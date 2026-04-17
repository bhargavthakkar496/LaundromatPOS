import type { Request, Response } from 'express';
import { z } from 'zod';

import { withTransaction } from '../db/transaction.js';
import { writeAuditLog } from '../services/audit.js';
import { generateReference } from '../services/security.js';
import { serializePaymentSession } from '../services/serializers.js';

const createPaymentSessionSchema = z.object({
  amount: z.number().positive(),
  paymentMethod: z.string().trim().min(1),
  referencePrefix: z.string().trim().min(1).optional(),
  attempt: z.number().int().positive().optional(),
  shouldFail: z.boolean().optional(),
});

const paymentSessionIdSchema = z.coerce.number().int().positive();

type PaymentSessionRow = {
  id: number;
  amount: number | string;
  payment_method: string;
  reference: string;
  qr_payload: string;
  status: string;
  attempt: number;
  created_at: Date | string;
  checked_at: Date | string;
  failure_reason: string | null;
  should_fail?: boolean;
};

export async function createPaymentSessionHandler(
  request: Request,
  response: Response,
) {
  const parsed = createPaymentSessionSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_request',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;
  const result = await withTransaction(async (client) => {
    const reference = generateReference(parsed.data.referencePrefix ?? 'PAY');
    const inserted = await client.query<PaymentSessionRow>(
      `
        INSERT INTO payment_sessions (
          amount,
          payment_method,
          reference,
          qr_payload,
          status,
          attempt,
          should_fail,
          created_at,
          checked_at
        ) VALUES ($1,$2,$3,$4,'AWAITING_SCAN',$5,$6,NOW(),NOW())
        RETURNING
          id,
          amount,
          payment_method,
          reference,
          qr_payload,
          status,
          attempt,
          created_at,
          checked_at,
          failure_reason
      `,
      [
        parsed.data.amount,
        parsed.data.paymentMethod,
        reference,
        `upi://pay?am=${parsed.data.amount.toFixed(2)}`,
        parsed.data.attempt ?? 1,
        parsed.data.shouldFail ?? false,
      ],
    );
    const session = inserted.rows[0];
    await writeAuditLog(client, {
      actorType: 'USER',
      actorUserId: authUserId ?? null,
      action: 'payment_session.create',
      entityType: 'payment_session',
      entityId: String(session.id),
      afterState: serializePaymentSession(session),
    });
    return session;
  });

  response.json(serializePaymentSession(result));
}

export async function getPaymentSessionHandler(
  request: Request,
  response: Response,
) {
  const parsedId = paymentSessionIdSchema.safeParse(request.params.sessionId);
  if (!parsedId.success) {
    response.status(400).json({
      error: 'invalid_session_id',
    });
    return;
  }

  const result = await withTransaction(async (client) => {
    const existing = await client.query<PaymentSessionRow>(
      `
        SELECT
          id,
          amount,
          payment_method,
          reference,
          qr_payload,
          status,
          attempt,
          created_at,
          checked_at,
          failure_reason,
          should_fail
        FROM payment_sessions
        WHERE id = $1
        FOR UPDATE
      `,
      [parsedId.data],
    );

    if (existing.rowCount === 0) {
      return null;
    }

    const row = existing.rows[0];
    const createdAt = new Date(row.created_at);
    const secondsElapsed = Math.floor((Date.now() - createdAt.getTime()) / 1000);
    const nextStatus =
      secondsElapsed >= 8
        ? row.should_fail
          ? 'FAILED'
          : 'PAID'
        : secondsElapsed >= 4
          ? 'PROCESSING'
          : 'AWAITING_SCAN';
    const failureReason =
      nextStatus === 'FAILED'
        ? 'The bank did not confirm this payment in time. Please retry with the same QR flow.'
        : null;

    const updated = await client.query<PaymentSessionRow>(
      `
        UPDATE payment_sessions
        SET status = $2,
            checked_at = NOW(),
            failure_reason = $3
        WHERE id = $1
        RETURNING
          id,
          amount,
          payment_method,
          reference,
          qr_payload,
          status,
          attempt,
          created_at,
          checked_at,
          failure_reason
      `,
      [parsedId.data, nextStatus, failureReason],
    );

    return updated.rows[0];
  });

  if (result == null) {
    response.status(404).json({
      error: 'not_found',
      detail: 'Payment session not found',
    });
    return;
  }

  response.json(serializePaymentSession(result));
}
