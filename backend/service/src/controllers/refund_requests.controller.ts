import type { Request, Response } from "express";
import { z } from "zod";

import { query, withTransaction } from "../db/transaction.js";
import { writeAuditLog } from "../services/audit.js";
import { serializeRefundRequest } from "../services/serializers.js";

type RefundRequestRow = {
  id: number;
  order_id: number;
  reason: string;
  status: string;
  requested_at: Date | string;
  requested_by_name: string | null;
  processed_at: Date | string | null;
  processed_by_name: string | null;
  customer_full_name: string;
  customer_phone: string;
  machine_name: string;
  amount: number | string;
  payment_method: string;
  payment_reference: string;
};

const refundRequestIdSchema = z.coerce.number().int().positive();
const listRefundRequestsSchema = z.object({
  status: z.enum(["PENDING", "PROCESSED"]).optional(),
});
const createRefundRequestSchema = z.object({
  orderId: z.number().int().positive(),
  reason: z.string().trim().min(5).max(500),
  requestedByName: z.string().trim().min(1).max(120).optional(),
});
const processRefundRequestSchema = z.object({
  processedByName: z.string().trim().min(1).max(120).optional(),
});

async function fetchRefundRequestRows(status?: string, requestId?: number) {
  const values: unknown[] = [];
  const where: string[] = [];

  if (status != null) {
    values.push(status);
    where.push(`rr.status = $${values.length}`);
  }

  if (requestId != null) {
    values.push(requestId);
    where.push(`rr.id = $${values.length}`);
  }

  const whereClause = where.length > 0 ? `WHERE ${where.join(" AND ")}` : "";

  return query<RefundRequestRow>(
    `
      SELECT
        rr.id,
        rr.order_id,
        rr.reason,
        rr.status,
        rr.requested_at,
        rr.requested_by_name,
        rr.processed_at,
        rr.processed_by_name,
        c.full_name AS customer_full_name,
        c.phone AS customer_phone,
        m.name AS machine_name,
        o.amount,
        o.payment_method,
        o.payment_reference
      FROM refund_requests rr
      JOIN orders o ON o.id = rr.order_id
      JOIN customers c ON c.id = o.customer_id
      JOIN machines m ON m.id = o.machine_id
      ${whereClause}
      ORDER BY
        CASE WHEN rr.status = 'PENDING' THEN 0 ELSE 1 END,
        rr.requested_at DESC
    `,
    values,
  );
}

async function fetchRefundRequestRowsByIdWithClient(
  client: {
    query: <T>(text: string, values?: unknown[]) => Promise<{ rows: T[] }>;
  },
  requestId: number,
) {
  return client.query<RefundRequestRow>(
    `
      SELECT
        rr.id,
        rr.order_id,
        rr.reason,
        rr.status,
        rr.requested_at,
        rr.requested_by_name,
        rr.processed_at,
        rr.processed_by_name,
        c.full_name AS customer_full_name,
        c.phone AS customer_phone,
        m.name AS machine_name,
        o.amount,
        o.payment_method,
        o.payment_reference
      FROM refund_requests rr
      JOIN orders o ON o.id = rr.order_id
      JOIN customers c ON c.id = o.customer_id
      JOIN machines m ON m.id = o.machine_id
      WHERE rr.id = $1
    `,
    [requestId],
  );
}

export async function listRefundRequestsHandler(
  request: Request,
  response: Response,
) {
  const parsed = listRefundRequestsSchema.safeParse(request.query);
  if (!parsed.success) {
    response.status(400).json({ error: "invalid_refund_request_query" });
    return;
  }

  const result = await fetchRefundRequestRows(parsed.data.status);
  response.json(result.rows.map((row) => serializeRefundRequest(row)));
}

export async function createRefundRequestHandler(
  request: Request,
  response: Response,
) {
  const parsed = createRefundRequestSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({ error: "invalid_refund_request_payload" });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;

  try {
    const created = await withTransaction(async (client) => {
      const orderResult = await client.query<{
        id: number;
        payment_status: string;
      }>(
        `
          SELECT id, payment_status
          FROM orders
          WHERE id = $1
          FOR UPDATE
        `,
        [parsed.data.orderId],
      );

      if (orderResult.rowCount === 0) {
        return null;
      }

      if (orderResult.rows[0].payment_status !== "PAID") {
        throw new Error("Only paid orders can enter the refund queue");
      }

      const existing = await client.query<RefundRequestRow>(
        `
          SELECT
            rr.id,
            rr.order_id,
            rr.reason,
            rr.status,
            rr.requested_at,
            rr.requested_by_name,
            rr.processed_at,
            rr.processed_by_name,
            c.full_name AS customer_full_name,
            c.phone AS customer_phone,
            m.name AS machine_name,
            o.amount,
            o.payment_method,
            o.payment_reference
          FROM refund_requests rr
          JOIN orders o ON o.id = rr.order_id
          JOIN customers c ON c.id = o.customer_id
          JOIN machines m ON m.id = o.machine_id
          WHERE rr.order_id = $1 AND rr.status = 'PENDING'
          LIMIT 1
        `,
        [parsed.data.orderId],
      );

      if (existing.rows.length > 0) {
        return existing.rows[0];
      }

      const inserted = await client.query<RefundRequestRow>(
        `
          INSERT INTO refund_requests (
            order_id,
            reason,
            requested_by_name,
            status
          )
          VALUES ($1, $2, $3, 'PENDING')
          RETURNING id, order_id, reason, status, requested_at, requested_by_name, processed_at, processed_by_name
        `,
        [
          parsed.data.orderId,
          parsed.data.reason,
          parsed.data.requestedByName ?? null,
        ],
      );

      const hydrated = await fetchRefundRequestRowsByIdWithClient(
        client,
        inserted.rows[0].id,
      );
      const requestRow = hydrated.rows[0];

      await writeAuditLog(client, {
        actorType: "USER",
        actorUserId: authUserId ?? null,
        action: "refund.request_created",
        entityType: "refund_request",
        entityId: String(requestRow.id),
        afterState: serializeRefundRequest(requestRow),
        metadata: {
          orderId: requestRow.order_id,
        },
      });

      return requestRow;
    });

    if (created == null) {
      response.status(404).json({ error: "not_found", detail: "Order not found" });
      return;
    }

    response.json(serializeRefundRequest(created));
  } catch (error) {
    response.status(400).json({
      error: "refund_request_create_failed",
      detail: error instanceof Error ? error.message : "Unknown error",
    });
  }
}

export async function processRefundRequestHandler(
  request: Request,
  response: Response,
) {
  const parsedId = refundRequestIdSchema.safeParse(request.params.requestId);
  const parsedBody = processRefundRequestSchema.safeParse(request.body ?? {});
  if (!parsedId.success || !parsedBody.success) {
    response.status(400).json({ error: "invalid_refund_request_payload" });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;

  try {
    const updated = await withTransaction(async (client) => {
      const current = await client.query<RefundRequestRow>(
        `
          SELECT
            rr.id,
            rr.order_id,
            rr.reason,
            rr.status,
            rr.requested_at,
            rr.requested_by_name,
            rr.processed_at,
            rr.processed_by_name,
            c.full_name AS customer_full_name,
            c.phone AS customer_phone,
            m.name AS machine_name,
            o.amount,
            o.payment_method,
            o.payment_reference
          FROM refund_requests rr
          JOIN orders o ON o.id = rr.order_id
          JOIN customers c ON c.id = o.customer_id
          JOIN machines m ON m.id = o.machine_id
          WHERE rr.id = $1
          FOR UPDATE
        `,
        [parsedId.data],
      );

      if (current.rowCount === 0) {
        return null;
      }

      const before = current.rows[0];
      if (before.status === "PROCESSED") {
        return before;
      }

      await client.query(
        `
          UPDATE orders
          SET payment_status = 'REFUNDED',
              updated_at = NOW()
          WHERE id = $1
        `,
        [before.order_id],
      );

      await client.query(
        `
          UPDATE payments
          SET payment_status = 'REFUNDED',
              settled_at = NOW()
          WHERE order_id = $1
        `,
        [before.order_id],
      );

      await client.query(
        `
          UPDATE refund_requests
          SET status = 'PROCESSED',
              processed_at = NOW(),
              processed_by_name = $2,
              updated_at = NOW()
          WHERE id = $1
        `,
        [parsedId.data, parsedBody.data.processedByName ?? null],
      );

      const hydrated = await fetchRefundRequestRowsByIdWithClient(
        client,
        parsedId.data,
      );
      const after = hydrated.rows[0];

      await writeAuditLog(client, {
        actorType: "USER",
        actorUserId: authUserId ?? null,
        action: "refund.request_processed",
        entityType: "refund_request",
        entityId: String(parsedId.data),
        beforeState: serializeRefundRequest(before),
        afterState: serializeRefundRequest(after),
        metadata: {
          orderId: after.order_id,
        },
      });

      return after;
    });

    if (updated == null) {
      response.status(404).json({ error: "not_found", detail: "Refund request not found" });
      return;
    }

    response.json(serializeRefundRequest(updated));
  } catch (error) {
    response.status(400).json({
      error: "refund_request_process_failed",
      detail: error instanceof Error ? error.message : "Unknown error",
    });
  }
}