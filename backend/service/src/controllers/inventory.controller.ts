import type { Request, Response } from "express";
import { z } from "zod";

import { query, withTransaction } from "../db/transaction.js";
import { writeAuditLog } from "../services/audit.js";
import {
  serializeInventoryCategorySummary,
  serializeInventoryDashboard,
  serializeInventoryItem,
  serializeInventoryRestockRequest,
  serializeInventoryStockMovement,
} from "../services/serializers.js";

type InventoryDashboardRow = {
  low_stock_count: number | string;
  out_of_stock_count: number | string;
  stock_value: number | string | null;
  pending_purchase_orders: number | string;
  expiring_soon_count: number | string;
};

type InventoryCategoryRow = {
  category: string;
  item_count: number | string;
  low_stock_count: number | string;
  out_of_stock_count: number | string;
};

type InventoryItemRow = {
  id: number;
  sku: string;
  barcode: string | null;
  name: string;
  category: string;
  supplier_name: string | null;
  branch_name: string;
  location_name: string;
  unit: string;
  unit_type: string;
  pack_size: string | null;
  quantity_on_hand: number | string;
  reorder_point: number | string;
  par_level: number | string;
  unit_cost: number | string;
  selling_price: number | string | null;
  stock_value: number | string;
  last_restocked_at: Date | string | null;
  expires_at: Date | string | null;
  stock_status: string;
  is_active: boolean;
  reorder_urgency_score: number | string;
  active_restock_request_id: number | null;
  active_restock_request_status: string | null;
  active_restock_request_number: string | null;
  active_restock_requested_quantity: number | string | null;
  active_restock_operator_remarks: string | null;
  active_restock_approved_at: Date | string | null;
};

type InventoryStockMovementRow = {
  id: number;
  inventory_item_id: number;
  movement_type: string;
  quantity_delta: number | string;
  balance_after: number | string;
  reference_type: string | null;
  reference_id: string | null;
  notes: string | null;
  performed_by_name: string | null;
  occurred_at: Date | string;
};

type InventoryRestockRequestRow = {
  id: number;
  request_number: string;
  inventory_item_id: number;
  item_name: string;
  item_sku: string;
  item_category: string;
  supplier_name: string | null;
  branch_name: string;
  location_name: string;
  unit: string;
  requested_quantity: number | string;
  status: string;
  request_notes: string | null;
  operator_remarks: string | null;
  requested_by_name: string | null;
  approved_by_name: string | null;
  created_at: Date | string;
  approved_at: Date | string | null;
};

type InventoryItemForRequestRow = {
  id: number;
  sku: string;
  name: string;
  category: string;
  unit: string;
  supplier_id: number | null;
  supplier_name: string | null;
  branch_name: string;
  location_name: string;
  quantity_on_hand: number;
  reorder_point: number;
};

const inventoryItemsQuerySchema = z.object({
  q: z.string().trim().optional(),
  category: z.string().trim().optional(),
  stockStatus: z
    .enum(["HEALTHY", "LOW", "OUT_OF_STOCK", "IN_PROCUREMENT"])
    .optional(),
  supplier: z.string().trim().optional(),
  branch: z.string().trim().optional(),
  location: z.string().trim().optional(),
  sortBy: z.enum(["quantity", "lastRestockedAt", "reorderUrgency"]).optional(),
  sortOrder: z.enum(["asc", "desc"]).optional(),
});

const restockRequestsQuerySchema = z.object({
  status: z.enum(["PENDING", "APPROVED", "PROCURED"]).optional(),
});

const createRestockRequestSchema = z.object({
  inventoryItemId: z.coerce.number().int().positive(),
  requestedQuantity: z.coerce.number().int().positive(),
  requestNotes: z.string().trim().max(500).nullish(),
});

const approveRestockRequestSchema = z.object({
  operatorRemarks: z.string().trim().min(1).max(500),
});

const restockRequestIdSchema = z.coerce.number().int().positive();
const inventoryItemIdSchema = z.coerce.number().int().positive();

function normalizeOptionalFilter(value?: string) {
  if (value == null) {
    return null;
  }
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function restockRequestQuery(whereClause = "TRUE") {
  return `
    SELECT
      r.id,
      r.request_number,
      r.inventory_item_id,
      i.name AS item_name,
      i.sku AS item_sku,
      i.category AS item_category,
      s.name AS supplier_name,
      i.branch_name,
      i.location_name,
      i.unit,
      r.requested_quantity,
      r.status,
      r.request_notes,
      r.operator_remarks,
      requester.display_name AS requested_by_name,
      approver.display_name AS approved_by_name,
      r.created_at,
      r.approved_at
    FROM inventory_restock_requests r
    JOIN inventory_items i ON i.id = r.inventory_item_id
    LEFT JOIN inventory_suppliers s ON s.id = i.supplier_id
    LEFT JOIN users requester ON requester.id = r.requested_by_user_id
    LEFT JOIN users approver ON approver.id = r.approved_by_user_id
    WHERE ${whereClause}
  `;
}

async function fetchRestockRequestById(restockRequestId: number) {
  const result = await query<InventoryRestockRequestRow>(
    `
      ${restockRequestQuery("r.id = $1")}
      ORDER BY r.created_at DESC
    `,
    [restockRequestId],
  );
  return result.rows[0] ?? null;
}

export async function getInventoryDashboardHandler(
  _request: Request,
  response: Response,
) {
  const [
    dashboardResult,
    categoryResult,
    supplierResult,
    branchResult,
    locationResult,
  ] = await Promise.all([
    query<InventoryDashboardRow>(
      `
        WITH inventory_state AS (
          SELECT
            i.quantity_on_hand,
            i.reorder_point,
            i.unit_cost,
            i.expires_at,
            CASE
              WHEN active_request.status = 'APPROVED' THEN 'IN_PROCUREMENT'
              WHEN i.quantity_on_hand = 0 THEN 'OUT_OF_STOCK'
              WHEN i.quantity_on_hand <= i.reorder_point THEN 'LOW'
              ELSE 'HEALTHY'
            END AS stock_status
          FROM inventory_items i
          LEFT JOIN LATERAL (
            SELECT r.status
            FROM inventory_restock_requests r
            WHERE r.inventory_item_id = i.id
              AND r.status IN ('PENDING', 'APPROVED')
            ORDER BY r.created_at DESC
            LIMIT 1
          ) active_request ON TRUE
          WHERE i.is_active = TRUE
        )
        SELECT
          COUNT(*) FILTER (
            WHERE stock_status = 'LOW'
          ) AS low_stock_count,
          COUNT(*) FILTER (
            WHERE stock_status = 'OUT_OF_STOCK'
          ) AS out_of_stock_count,
          COALESCE(SUM(quantity_on_hand * unit_cost), 0) AS stock_value,
          (
            SELECT COUNT(*)
            FROM inventory_purchase_orders
            WHERE UPPER(status) IN ('PENDING', 'APPROVED', 'ORDERED')
          ) AS pending_purchase_orders,
          COUNT(*) FILTER (
            WHERE expires_at IS NOT NULL
              AND expires_at >= CURRENT_DATE
              AND expires_at <= CURRENT_DATE + INTERVAL '30 days'
              AND quantity_on_hand > 0
          ) AS expiring_soon_count
        FROM inventory_state
      `,
    ),
    query<InventoryCategoryRow>(
      `
        WITH inventory_state AS (
          SELECT
            i.category,
            CASE
              WHEN active_request.status = 'APPROVED' THEN 'IN_PROCUREMENT'
              WHEN i.quantity_on_hand = 0 THEN 'OUT_OF_STOCK'
              WHEN i.quantity_on_hand <= i.reorder_point THEN 'LOW'
              ELSE 'HEALTHY'
            END AS stock_status
          FROM inventory_items i
          LEFT JOIN LATERAL (
            SELECT r.status
            FROM inventory_restock_requests r
            WHERE r.inventory_item_id = i.id
              AND r.status IN ('PENDING', 'APPROVED')
            ORDER BY r.created_at DESC
            LIMIT 1
          ) active_request ON TRUE
          WHERE i.is_active = TRUE
        )
        SELECT
          category,
          COUNT(*) AS item_count,
          COUNT(*) FILTER (
            WHERE stock_status = 'LOW'
          ) AS low_stock_count,
          COUNT(*) FILTER (
            WHERE stock_status = 'OUT_OF_STOCK'
          ) AS out_of_stock_count
        FROM inventory_state
        GROUP BY category
        ORDER BY category ASC
      `,
    ),
    query<{ supplier: string }>(
      `
        SELECT DISTINCT s.name AS supplier
        FROM inventory_items i
        LEFT JOIN inventory_suppliers s ON s.id = i.supplier_id
        WHERE i.is_active = TRUE
          AND s.name IS NOT NULL
        ORDER BY s.name ASC
      `,
    ),
    query<{ branch: string }>(
      `
        SELECT DISTINCT branch_name AS branch
        FROM inventory_items
        WHERE is_active = TRUE
        ORDER BY branch_name ASC
      `,
    ),
    query<{ location: string }>(
      `
        SELECT DISTINCT location_name AS location
        FROM inventory_items
        WHERE is_active = TRUE
        ORDER BY location_name ASC
      `,
    ),
  ]);

  response.json({
    metrics: serializeInventoryDashboard(dashboardResult.rows[0]),
    categories: categoryResult.rows.map((row) =>
      serializeInventoryCategorySummary(row),
    ),
    suppliers: supplierResult.rows.map((row) => row.supplier),
    branches: branchResult.rows.map((row) => row.branch),
    locations: locationResult.rows.map((row) => row.location),
  });
}

export async function listInventoryItemsHandler(
  request: Request,
  response: Response,
) {
  const parsed = inventoryItemsQuerySchema.safeParse(request.query);
  if (!parsed.success) {
    response.status(400).json({
      error: "invalid_request",
      detail: parsed.error.flatten(),
    });
    return;
  }

  const search = normalizeOptionalFilter(parsed.data.q);
  const category = normalizeOptionalFilter(parsed.data.category);
  const supplier = normalizeOptionalFilter(parsed.data.supplier);
  const branch = normalizeOptionalFilter(parsed.data.branch);
  const location = normalizeOptionalFilter(parsed.data.location);
  const sortBy = parsed.data.sortBy ?? "reorderUrgency";
  const sortOrder = parsed.data.sortOrder ?? "desc";

  const values: unknown[] = [];
  const filters = ["i.is_active = TRUE"];

  if (search != null) {
    values.push(`%${search}%`);
    const index = values.length;
    filters.push(`(i.name ILIKE $${index} OR i.sku ILIKE $${index})`);
  }
  if (category != null) {
    values.push(category);
    filters.push(`i.category = $${values.length}`);
  }
  if (supplier != null) {
    values.push(supplier);
    filters.push(`s.name = $${values.length}`);
  }
  if (branch != null) {
    values.push(branch);
    filters.push(`i.branch_name = $${values.length}`);
  }
  if (location != null) {
    values.push(location);
    filters.push(`i.location_name = $${values.length}`);
  }
  if (parsed.data.stockStatus != null) {
    switch (parsed.data.stockStatus) {
      case "OUT_OF_STOCK":
        filters.push(
          "active_request.status IS DISTINCT FROM 'APPROVED' AND i.quantity_on_hand = 0",
        );
        break;
      case "LOW":
        filters.push(
          "active_request.status IS DISTINCT FROM 'APPROVED' AND i.quantity_on_hand > 0 AND i.quantity_on_hand <= i.reorder_point",
        );
        break;
      case "IN_PROCUREMENT":
        filters.push("active_request.status = 'APPROVED'");
        break;
      case "HEALTHY":
        filters.push(
          "active_request.status IS DISTINCT FROM 'APPROVED' AND i.quantity_on_hand > i.reorder_point",
        );
        break;
    }
  }

  const orderByClause = (() => {
    switch (sortBy) {
      case "quantity":
        return `i.quantity_on_hand ${sortOrder.toUpperCase()}, i.name ASC`;
      case "lastRestockedAt":
        return `i.last_restocked_at ${sortOrder.toUpperCase()} NULLS LAST, i.name ASC`;
      case "reorderUrgency":
      default:
        return `reorder_urgency_score ${sortOrder.toUpperCase()}, i.quantity_on_hand ASC, i.name ASC`;
    }
  })();

  const result = await query<InventoryItemRow>(
    `
      SELECT
        i.id,
        i.sku,
        i.barcode,
        i.name,
        i.category,
        s.name AS supplier_name,
        i.branch_name,
        i.location_name,
        i.unit,
        i.unit_type,
        i.pack_size,
        i.quantity_on_hand,
        i.reorder_point,
        i.par_level,
        i.unit_cost,
        i.selling_price,
        (i.quantity_on_hand * i.unit_cost) AS stock_value,
        i.last_restocked_at,
        i.expires_at,
        CASE
          WHEN active_request.status = 'APPROVED' THEN 'IN_PROCUREMENT'
          WHEN i.quantity_on_hand = 0 THEN 'OUT_OF_STOCK'
          WHEN i.quantity_on_hand <= i.reorder_point THEN 'LOW'
          ELSE 'HEALTHY'
        END AS stock_status,
        CASE
          WHEN active_request.status = 'APPROVED' THEN GREATEST(i.reorder_point, 1)
          ELSE GREATEST(i.reorder_point - i.quantity_on_hand, 0)
        END AS reorder_urgency_score,
        i.is_active,
        active_request.id AS active_restock_request_id,
        active_request.status AS active_restock_request_status,
        active_request.request_number AS active_restock_request_number,
        active_request.requested_quantity AS active_restock_requested_quantity,
        active_request.operator_remarks AS active_restock_operator_remarks,
        active_request.approved_at AS active_restock_approved_at
      FROM inventory_items i
      LEFT JOIN inventory_suppliers s ON s.id = i.supplier_id
      LEFT JOIN LATERAL (
        SELECT
          r.id,
          r.status,
          r.request_number,
          r.requested_quantity,
          r.operator_remarks,
          r.approved_at
        FROM inventory_restock_requests r
        WHERE r.inventory_item_id = i.id
          AND r.status IN ('PENDING', 'APPROVED')
        ORDER BY r.created_at DESC
        LIMIT 1
      ) active_request ON TRUE
      WHERE ${filters.join("\n        AND ")}
      ORDER BY ${orderByClause}
    `,
    values,
  );

  response.json(result.rows.map((row) => serializeInventoryItem(row)));
}

export async function listInventoryItemMovementsHandler(
  request: Request,
  response: Response,
) {
  const parsedId = inventoryItemIdSchema.safeParse(request.params.inventoryItemId);
  if (!parsedId.success) {
    response.status(400).json({
      error: "invalid_inventory_item_id",
    });
    return;
  }

  const itemResult = await query<{ id: number }>(
    `
      SELECT id
      FROM inventory_items
      WHERE id = $1
        AND is_active = TRUE
    `,
    [parsedId.data],
  );
  if (itemResult.rowCount === 0) {
    response.status(404).json({
      error: "not_found",
      detail: "Inventory item not found",
    });
    return;
  }

  const result = await query<InventoryStockMovementRow>(
    `
      SELECT
        m.id,
        m.inventory_item_id,
        m.movement_type,
        m.quantity_delta,
        m.balance_after,
        m.reference_type,
        m.reference_id,
        m.notes,
        performer.display_name AS performed_by_name,
        m.occurred_at
      FROM inventory_stock_movements m
      LEFT JOIN users performer ON performer.id = m.performed_by_user_id
      WHERE m.inventory_item_id = $1
      ORDER BY m.occurred_at DESC, m.id DESC
    `,
    [parsedId.data],
  );

  response.json(result.rows.map((row) => serializeInventoryStockMovement(row)));
}

export async function listInventoryRestockRequestsHandler(
  request: Request,
  response: Response,
) {
  const parsed = restockRequestsQuerySchema.safeParse(request.query);
  if (!parsed.success) {
    response.status(400).json({
      error: "invalid_request",
      detail: parsed.error.flatten(),
    });
    return;
  }

  const values: unknown[] = [];
  let whereClause = "TRUE";
  if (parsed.data.status != null) {
    values.push(parsed.data.status);
    whereClause = "r.status = $1";
  }

  const result = await query<InventoryRestockRequestRow>(
    `
      ${restockRequestQuery(whereClause)}
      ORDER BY r.created_at DESC
    `,
    values,
  );

  response.json(
    result.rows.map((row) => serializeInventoryRestockRequest(row)),
  );
}

export async function createInventoryRestockRequestHandler(
  request: Request,
  response: Response,
) {
  const parsed = createRestockRequestSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({
      error: "invalid_request",
      detail: parsed.error.flatten(),
    });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;

  const created = await withTransaction(async (client) => {
    const itemResult = await client.query<InventoryItemForRequestRow>(
      `
        SELECT
          i.id,
          i.sku,
          i.name,
          i.category,
          i.unit,
          i.supplier_id,
          i.branch_name,
          i.location_name,
          i.quantity_on_hand,
          i.reorder_point
        FROM inventory_items i
        WHERE i.id = $1
          AND i.is_active = TRUE
        FOR UPDATE
      `,
      [parsed.data.inventoryItemId],
    );

    if (itemResult.rowCount === 0) {
      return { type: "not_found" as const };
    }

    const item = itemResult.rows[0];
    if (Number(item.quantity_on_hand) !== 0) {
      return { type: "invalid_stock_state" as const };
    }

    const pendingExistingResult = await client.query<{ id: number }>(
      `
        SELECT id
        FROM inventory_restock_requests
        WHERE inventory_item_id = $1
          AND status = 'PENDING'
        ORDER BY created_at DESC
        LIMIT 1
      `,
      [parsed.data.inventoryItemId],
    );

    if ((pendingExistingResult.rowCount ?? 0) > 0) {
      return { type: "duplicate_pending" as const };
    }

    const requestNumber = `RSTK-${Date.now()}`;
    const insertResult = await client.query<{ id: number }>(
      `
        INSERT INTO inventory_restock_requests (
          request_number,
          inventory_item_id,
          requested_quantity,
          status,
          request_notes,
          requested_by_user_id,
          created_at,
          updated_at
        ) VALUES ($1, $2, $3, 'PENDING', $4, $5, NOW(), NOW())
        RETURNING id
      `,
      [
        requestNumber,
        parsed.data.inventoryItemId,
        parsed.data.requestedQuantity,
        parsed.data.requestNotes ?? null,
        authUserId ?? null,
      ],
    );

    const createdRequest = await client.query<InventoryRestockRequestRow>(
      `
        ${restockRequestQuery("r.id = $1")}
      `,
      [insertResult.rows[0].id],
    );

    const serialized = serializeInventoryRestockRequest(createdRequest.rows[0]);
    await writeAuditLog(client, {
      actorType: "USER",
      actorUserId: authUserId ?? null,
      action: "inventory.restock_request.create",
      entityType: "inventory_restock_request",
      entityId: String(insertResult.rows[0].id),
      afterState: serialized,
      metadata: {
        inventoryItemId: parsed.data.inventoryItemId,
      },
    });

    return { type: "created" as const, request: serialized };
  });

  if (created.type === "not_found") {
    response.status(404).json({
      error: "not_found",
      detail: "Inventory item not found",
    });
    return;
  }
  if (created.type === "invalid_stock_state") {
    response.status(409).json({
      error: "invalid_stock_state",
      detail: "Restock requests can only be created for out-of-stock items",
    });
    return;
  }
  if (created.type === "duplicate_pending") {
    response.status(409).json({
      error: "duplicate_pending_request",
      detail: "A pending restock request already exists for this item",
    });
    return;
  }

  response.status(201).json(created.request);
}

export async function approveInventoryRestockRequestHandler(
  request: Request,
  response: Response,
) {
  const parsedId = restockRequestIdSchema.safeParse(
    request.params.restockRequestId,
  );
  if (!parsedId.success) {
    response.status(400).json({
      error: "invalid_restock_request_id",
    });
    return;
  }

  const parsedBody = approveRestockRequestSchema.safeParse(request.body);
  if (!parsedBody.success) {
    response.status(400).json({
      error: "invalid_request",
      detail: parsedBody.error.flatten(),
    });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;

  const updated = await withTransaction(async (client) => {
    const requestResult = await client.query<{
      id: number;
      inventory_item_id: number;
      supplier_id: number | null;
      branch_name: string;
      status: string;
    }>(
      `
        SELECT
          r.id,
          r.inventory_item_id,
          s.id AS supplier_id,
          i.branch_name,
          r.status
        FROM inventory_restock_requests r
        JOIN inventory_items i ON i.id = r.inventory_item_id
        LEFT JOIN inventory_suppliers s ON s.id = i.supplier_id
        WHERE r.id = $1
        FOR UPDATE OF r
      `,
      [parsedId.data],
    );

    if (requestResult.rowCount === 0) {
      return { type: "not_found" as const };
    }

    const existing = requestResult.rows[0];
    const beforeFull = await client.query<InventoryRestockRequestRow>(
      `
        ${restockRequestQuery("r.id = $1")}
      `,
      [parsedId.data],
    );

    if (existing.status !== "PENDING") {
      return { type: "already_processed" as const };
    }

    const updateResult = await client.query<{ id: number }>(
      `
        UPDATE inventory_restock_requests
        SET status = 'APPROVED',
            operator_remarks = $2,
            approved_by_user_id = $3,
            approved_at = NOW(),
            updated_at = NOW()
        WHERE id = $1
        RETURNING id
      `,
      [parsedId.data, parsedBody.data.operatorRemarks, authUserId ?? null],
    );

    await client.query(
      `
        SELECT setval(
          pg_get_serial_sequence('inventory_purchase_orders', 'id'),
          COALESCE((SELECT MAX(id) FROM inventory_purchase_orders), 0) + 1,
          false
        )
      `,
    );

    await client.query(
      `
        INSERT INTO inventory_purchase_orders (
          po_number,
          supplier_id,
          status,
          branch_name,
          expected_delivery_at,
          notes,
          restock_request_id,
          created_at,
          updated_at
        ) VALUES ($1, $2, 'PENDING', $3, NOW() + INTERVAL '2 days', $4, $5, NOW(), NOW())
      `,
      [
        `PO-RSTK-${Date.now()}`,
        existing.supplier_id,
        existing.branch_name,
        parsedBody.data.operatorRemarks,
        parsedId.data,
      ],
    );

    const finalRequest = await client.query<InventoryRestockRequestRow>(
      `
        ${restockRequestQuery("r.id = $1")}
      `,
      [updateResult.rows[0].id],
    );

    const beforeState = serializeInventoryRestockRequest(beforeFull.rows[0]);
    const afterState = serializeInventoryRestockRequest(finalRequest.rows[0]);
    await writeAuditLog(client, {
      actorType: "USER",
      actorUserId: authUserId ?? null,
      action: "inventory.restock_request.approve",
      entityType: "inventory_restock_request",
      entityId: String(parsedId.data),
      beforeState,
      afterState,
    });

    return { type: "approved" as const, request: afterState };
  });

  if (updated.type === "not_found") {
    response.status(404).json({
      error: "not_found",
      detail: "Restock request not found",
    });
    return;
  }
  if (updated.type === "already_processed") {
    response.status(409).json({
      error: "already_processed",
      detail: "Restock request has already been processed",
    });
    return;
  }

  response.json(updated.request);
}

export async function procureInventoryRestockRequestHandler(
  request: Request,
  response: Response,
) {
  const parsedId = restockRequestIdSchema.safeParse(
    request.params.restockRequestId,
  );
  if (!parsedId.success) {
    response.status(400).json({
      error: "invalid_restock_request_id",
    });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;

  const updated = await withTransaction(async (client) => {
    const requestResult = await client.query<{
      id: number;
      inventory_item_id: number;
      requested_quantity: number;
      reorder_point: number;
      quantity_on_hand: number;
      status: string;
    }>(
      `
        SELECT
          r.id,
          r.inventory_item_id,
          r.requested_quantity,
          i.reorder_point,
          i.quantity_on_hand,
          r.status
        FROM inventory_restock_requests r
        JOIN inventory_items i ON i.id = r.inventory_item_id
        WHERE r.id = $1
        FOR UPDATE OF r, i
      `,
      [parsedId.data],
    );

    if (requestResult.rowCount === 0) {
      return { type: "not_found" as const };
    }

    const existing = requestResult.rows[0];
    if (existing.status !== "APPROVED") {
      return { type: "invalid_state" as const, status: existing.status };
    }

    const beforeFull = await client.query<InventoryRestockRequestRow>(
      `
        ${restockRequestQuery("r.id = $1")}
      `,
      [parsedId.data],
    );

    await client.query(
      `
        UPDATE inventory_restock_requests
        SET status = 'PROCURED',
            updated_at = NOW()
        WHERE id = $1
      `,
      [parsedId.data],
    );

    await client.query(
      `
        UPDATE inventory_purchase_orders
        SET status = 'RECEIVED',
            updated_at = NOW()
        WHERE restock_request_id = $1
      `,
      [parsedId.data],
    );

    await client.query(
      `
        UPDATE inventory_items
        SET quantity_on_hand = GREATEST(
              quantity_on_hand + $2,
              reorder_point + 1
            ),
            last_restocked_at = NOW(),
            updated_at = NOW()
        WHERE id = $1
      `,
      [existing.inventory_item_id, existing.requested_quantity],
    );

    const itemBalanceResult = await client.query<{ quantity_on_hand: number }>(
      `
        SELECT quantity_on_hand
        FROM inventory_items
        WHERE id = $1
      `,
      [existing.inventory_item_id],
    );

    await client.query(
      `
        INSERT INTO inventory_stock_movements (
          inventory_item_id,
          movement_type,
          quantity_delta,
          balance_after,
          reference_type,
          reference_id,
          notes,
          performed_by_user_id,
          occurred_at
        ) VALUES ($1, 'RECEIVED', $2, $3, 'RESTOCK_REQUEST', $4, $5, $6, NOW())
      `,
      [
        existing.inventory_item_id,
        existing.requested_quantity,
        itemBalanceResult.rows[0].quantity_on_hand,
        String(parsedId.data),
        "Stock received against approved procurement request.",
        authUserId ?? null,
      ],
    );

    const finalRequest = await client.query<InventoryRestockRequestRow>(
      `
        ${restockRequestQuery("r.id = $1")}
      `,
      [parsedId.data],
    );

    const beforeState = serializeInventoryRestockRequest(beforeFull.rows[0]);
    const afterState = serializeInventoryRestockRequest(finalRequest.rows[0]);
    await writeAuditLog(client, {
      actorType: "USER",
      actorUserId: authUserId ?? null,
      action: "inventory.restock_request.procure",
      entityType: "inventory_restock_request",
      entityId: String(parsedId.data),
      beforeState,
      afterState,
      metadata: {
        inventoryItemId: existing.inventory_item_id,
      },
    });

    return { type: "procured" as const, request: afterState };
  });

  if (updated.type === "not_found") {
    response.status(404).json({
      error: "not_found",
      detail: "Restock request not found",
    });
    return;
  }
  if (updated.type === "invalid_state") {
    response.status(409).json({
      error: "invalid_state",
      detail: `Only approved restock requests can be marked procured. Current status: ${updated.status}`,
    });
    return;
  }

  response.json(updated.request);
}
