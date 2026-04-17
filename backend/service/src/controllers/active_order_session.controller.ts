import type { Request, Response } from 'express';
import { z } from 'zod';

import { query, withTransaction } from '../db/transaction.js';
import { writeAuditLog } from '../services/audit.js';
import { generateReference } from '../services/security.js';
import { serializeActiveOrderSession } from '../services/serializers.js';

const serviceEnum = z.enum(['Washing', 'Drying', 'Ironing']);

type ActiveOrderSessionRow = {
  id: number;
  customer_name: string;
  customer_phone: string;
  load_size_kg: number;
  selected_services: string[] | null;
  wash_option: string | null;
  washer_machine_id: number | null;
  dryer_machine_id: number | null;
  ironing_machine_id: number | null;
  payment_method: string;
  stage: string;
  created_at: Date | string;
  confirmed_by: string | null;
  order_id: number | null;
  payment_reference: string | null;
  is_active: boolean;
};

type MachineRow = {
  id: number;
  type: string;
  price: number | string;
};

const saveDraftSchema = z.object({
  customerName: z.string().trim().min(1),
  customerPhone: z.string().trim().min(1),
  loadSizeKg: z.number().int().positive(),
  selectedServices: z.array(serviceEnum).min(1),
  washOption: z.string().trim().min(1).nullable().optional(),
  washerMachineId: z.number().int().positive().nullable().optional(),
  dryerMachineId: z.number().int().positive().nullable().optional(),
  ironingMachineId: z.number().int().positive().nullable().optional(),
  paymentMethod: z.string().trim().min(1),
});

const confirmSchema = z.object({
  confirmedBy: z.string().trim().min(1),
  userId: z.number().int().positive().nullable().optional(),
});

const completePaymentSchema = z.object({
  paymentReference: z.string().trim().min(1),
});

function includesService(selectedServices: string[], service: string) {
  return selectedServices.includes(service);
}

function validateSelectedServices(input: {
  selectedServices: string[];
  washOption?: string | null;
  washerMachineId?: number | null;
  dryerMachineId?: number | null;
  ironingMachineId?: number | null;
}) {
  if (
    includesService(input.selectedServices, 'Washing') &&
    (input.washerMachineId == null || input.washOption == null)
  ) {
    return 'Washing requires both a wash option and washer assignment';
  }
  if (
    includesService(input.selectedServices, 'Drying') &&
    input.dryerMachineId == null
  ) {
    return 'Drying requires a dryer assignment';
  }
  if (
    includesService(input.selectedServices, 'Ironing') &&
    input.ironingMachineId == null
  ) {
    return 'Ironing requires an ironing station assignment';
  }
  return null;
}

function cycleDurationMinutes(machineType: string) {
  const normalized = machineType.toLowerCase();
  if (normalized === 'washer') {
    return 35;
  }
  if (normalized === 'dryer') {
    return 25;
  }
  return 20;
}

function primaryMachineId(row: ActiveOrderSessionRow) {
  return row.washer_machine_id ?? row.dryer_machine_id ?? row.ironing_machine_id;
}

function buildMachineIds(row: ActiveOrderSessionRow) {
  return [
    row.washer_machine_id,
    row.dryer_machine_id,
    row.ironing_machine_id,
  ].filter((value): value is number => value != null);
}

function serviceTypeLabel(selectedServices: string[]) {
  return selectedServices.map((item) => item.toUpperCase()).join('+');
}

async function getCurrentActiveSession() {
  const result = await query<ActiveOrderSessionRow>(
    `
      SELECT
        id,
        customer_name,
        customer_phone,
        load_size_kg,
        selected_services,
        wash_option,
        washer_machine_id,
        dryer_machine_id,
        ironing_machine_id,
        payment_method,
        stage,
        created_at,
        confirmed_by,
        order_id,
        payment_reference,
        is_active
      FROM active_order_sessions
      WHERE is_active = TRUE
      ORDER BY updated_at DESC, id DESC
      LIMIT 1
    `,
  );
  return result.rows[0] ?? null;
}

export async function getActiveOrderSessionHandler(
  _request: Request,
  response: Response,
) {
  const session = await getCurrentActiveSession();
  if (session == null) {
    response.status(404).json({
      error: 'not_found',
      detail: 'No active order session',
    });
    return;
  }

  response.json(serializeActiveOrderSession(session));
}

export async function saveActiveOrderDraftHandler(
  request: Request,
  response: Response,
) {
  const parsed = saveDraftSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_request',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const validationError = validateSelectedServices(parsed.data);
  if (validationError != null) {
    response.status(400).json({
      error: 'invalid_request',
      detail: validationError,
    });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;
  const session = await withTransaction(async (client) => {
    await client.query(
      `
        UPDATE active_order_sessions
        SET is_active = FALSE,
            updated_at = NOW()
        WHERE is_active = TRUE
      `,
    );

    const inserted = await client.query<ActiveOrderSessionRow>(
      `
        INSERT INTO active_order_sessions (
          customer_name,
          customer_phone,
          load_size_kg,
          selected_services,
          wash_option,
          washer_machine_id,
          dryer_machine_id,
          ironing_machine_id,
          payment_method,
          stage,
          created_at,
          confirmed_by,
          order_id,
          payment_reference,
          is_active,
          updated_at
        ) VALUES ($1,$2,$3,$4::text[],$5,$6,$7,$8,$9,'DRAFT',NOW(),NULL,NULL,NULL,TRUE,NOW())
        RETURNING
          id,
          customer_name,
          customer_phone,
          load_size_kg,
          selected_services,
          wash_option,
          washer_machine_id,
          dryer_machine_id,
          ironing_machine_id,
          payment_method,
          stage,
          created_at,
          confirmed_by,
          order_id,
          payment_reference,
          is_active
      `,
      [
        parsed.data.customerName,
        parsed.data.customerPhone,
        parsed.data.loadSizeKg,
        parsed.data.selectedServices,
        parsed.data.washOption ?? null,
        parsed.data.washerMachineId ?? null,
        parsed.data.dryerMachineId ?? null,
        parsed.data.ironingMachineId ?? null,
        parsed.data.paymentMethod,
      ],
    );

    const row = inserted.rows[0];
    await writeAuditLog(client, {
      actorType: 'USER',
      actorUserId: authUserId ?? null,
      action: 'active_order_session.save_draft',
      entityType: 'active_order_session',
      entityId: String(row.id),
      afterState: serializeActiveOrderSession(row),
    });
    return row;
  });

  response.json(serializeActiveOrderSession(session));
}

export async function confirmActiveOrderSessionHandler(
  request: Request,
  response: Response,
) {
  const parsed = confirmSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_request',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const authUserId =
    (parsed.data.userId ?? response.locals.authUserId) as number | undefined;

  try {
    const session = await withTransaction(async (client) => {
      const sessionResult = await client.query<ActiveOrderSessionRow>(
        `
          SELECT
            id,
            customer_name,
            customer_phone,
            load_size_kg,
            selected_services,
            wash_option,
            washer_machine_id,
            dryer_machine_id,
            ironing_machine_id,
            payment_method,
            stage,
            created_at,
            confirmed_by,
            order_id,
            payment_reference,
            is_active
          FROM active_order_sessions
          WHERE is_active = TRUE
          ORDER BY updated_at DESC, id DESC
          LIMIT 1
          FOR UPDATE
        `,
      );
      if (sessionResult.rowCount === 0) {
        return null;
      }
      const current = sessionResult.rows[0];
      if (current.stage !== 'DRAFT') {
        return current;
      }

      const selectedServices = current.selected_services ?? [];
      const validationError = validateSelectedServices({
        selectedServices,
        washOption: current.wash_option,
        washerMachineId: current.washer_machine_id,
        dryerMachineId: current.dryer_machine_id,
        ironingMachineId: current.ironing_machine_id,
      });
      if (validationError != null) {
        throw new Error(validationError);
      }

      const customerResult = await client.query<{ id: number }>(
        `
          INSERT INTO customers (
            full_name,
            phone,
            preferred_washer_size_kg,
            created_at,
            updated_at
          ) VALUES ($1,$2,$3,NOW(),NOW())
          ON CONFLICT (phone)
          DO UPDATE SET
            full_name = EXCLUDED.full_name,
            preferred_washer_size_kg = EXCLUDED.preferred_washer_size_kg,
            updated_at = NOW()
          RETURNING id
        `,
        [current.customer_name, current.customer_phone, current.load_size_kg],
      );
      const customerId = customerResult.rows[0].id;

      const machineIds = buildMachineIds(current);
      const machinePrices = await client.query<MachineRow>(
        `
          SELECT id, type, price
          FROM machines
          WHERE id = ANY($1::bigint[])
        `,
        [machineIds],
      );

      if (machinePrices.rowCount !== machineIds.length) {
        throw new Error('Assigned machines not found');
      }

      const amount = machinePrices.rows.reduce(
        (sum, row) => sum + Number(row.price),
        0,
      );
      const paymentReference = generateReference('ORD');
      const primaryMachine = primaryMachineId(current);
      if (primaryMachine == null) {
        throw new Error('At least one machine assignment is required');
      }

      const insertedOrder = await client.query<{
        id: number;
        timestamp: Date | string;
      }>(
        `
          INSERT INTO orders (
            machine_id,
            customer_id,
            created_by_user_id,
            service_type,
            selected_services,
            amount,
            status,
            payment_method,
            payment_status,
            payment_reference,
            timestamp,
            load_size_kg,
            wash_option,
            dryer_machine_id,
            ironing_machine_id
          ) VALUES ($1,$2,$3,$4,$5::text[],$6,'BOOKED',$7,'PENDING',$8,NOW(),$9,$10,$11,$12)
          RETURNING id, timestamp
        `,
        [
          primaryMachine,
          customerId,
          authUserId ?? null,
          serviceTypeLabel(selectedServices),
          selectedServices,
          amount,
          current.payment_method,
          paymentReference,
          current.load_size_kg,
          current.wash_option,
          current.dryer_machine_id,
          current.ironing_machine_id,
        ],
      );

      const updatedSession = await client.query<ActiveOrderSessionRow>(
        `
          UPDATE active_order_sessions
          SET stage = 'BOOKED',
              confirmed_by = $2,
              order_id = $3,
              created_at = $4,
              updated_at = NOW()
          WHERE id = $1
          RETURNING
            id,
            customer_name,
            customer_phone,
            load_size_kg,
            selected_services,
            wash_option,
            washer_machine_id,
            dryer_machine_id,
            ironing_machine_id,
            payment_method,
            stage,
            created_at,
            confirmed_by,
            order_id,
            payment_reference,
            is_active
        `,
        [
          current.id,
          parsed.data.confirmedBy,
          insertedOrder.rows[0].id,
          new Date(insertedOrder.rows[0].timestamp).toISOString(),
        ],
      );

      const row = updatedSession.rows[0];
      await writeAuditLog(client, {
        actorType: 'USER',
        actorUserId: authUserId ?? null,
        action: 'active_order_session.confirm',
        entityType: 'active_order_session',
        entityId: String(row.id),
        beforeState: serializeActiveOrderSession(current),
        afterState: serializeActiveOrderSession(row),
        metadata: {
          orderId: row.order_id,
          paymentReference,
          selectedServices,
        },
      });
      return row;
    });

    if (session == null) {
      response.status(404).json({
        error: 'not_found',
        detail: 'No active order session',
      });
      return;
    }

    response.json(serializeActiveOrderSession(session));
  } catch (error) {
    response.status(400).json({
      error: 'active_order_session_confirm_failed',
      detail: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}

export async function completeActiveOrderPaymentHandler(
  request: Request,
  response: Response,
) {
  const parsed = completePaymentSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_request',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;

  try {
    const session = await withTransaction(async (client) => {
      const sessionResult = await client.query<ActiveOrderSessionRow>(
        `
          SELECT
            id,
            customer_name,
            customer_phone,
            load_size_kg,
            selected_services,
            wash_option,
            washer_machine_id,
            dryer_machine_id,
            ironing_machine_id,
            payment_method,
            stage,
            created_at,
            confirmed_by,
            order_id,
            payment_reference,
            is_active
          FROM active_order_sessions
          WHERE is_active = TRUE
          ORDER BY updated_at DESC, id DESC
          LIMIT 1
          FOR UPDATE
        `,
      );
      if (sessionResult.rowCount === 0) {
        return null;
      }
      const current = sessionResult.rows[0];
      if (current.order_id == null) {
        throw new Error('Active order session has no linked order');
      }

      const startMachineId = primaryMachineId(current);
      if (startMachineId == null) {
        throw new Error('Active order session has no machine assignment');
      }

      const machineResult = await client.query<MachineRow>(
        `
          SELECT id, type, price
          FROM machines
          WHERE id = $1
          FOR UPDATE
        `,
        [startMachineId],
      );
      if (machineResult.rowCount === 0) {
        throw new Error('Assigned machine not found');
      }
      const primaryMachine = machineResult.rows[0];
      const cycleStartedAt = new Date();
      const cycleEndsAt = new Date(
        cycleStartedAt.getTime() +
          cycleDurationMinutes(primaryMachine.type) * 60_000,
      );

      await client.query(
        `
          UPDATE orders
          SET status = 'IN_PROGRESS',
              payment_status = 'PAID',
              payment_reference = $2,
              updated_at = NOW()
          WHERE id = $1
        `,
        [current.order_id, parsed.data.paymentReference],
      );

      const amountResult = await client.query<{ amount: number | string }>(
        `SELECT amount FROM orders WHERE id = $1`,
        [current.order_id],
      );
      const amount = Number(amountResult.rows[0].amount);

      await client.query(
        `
          INSERT INTO payments (
            order_id,
            amount,
            payment_method,
            payment_status,
            reference,
            created_at,
            settled_at
          ) VALUES ($1,$2,$3,'PAID',$4,NOW(),NOW())
        `,
        [
          current.order_id,
          amount,
          current.payment_method,
          parsed.data.paymentReference,
        ],
      );

      await client.query(
        `
          UPDATE machines
          SET status = 'IN_USE',
              current_order_id = $2,
              cycle_started_at = $3,
              cycle_ends_at = $4,
              updated_at = NOW()
          WHERE id = $1
        `,
        [
          startMachineId,
          current.order_id,
          cycleStartedAt.toISOString(),
          cycleEndsAt.toISOString(),
        ],
      );

      await client.query(
        `
          INSERT INTO machine_events (
            machine_id,
            order_id,
            event_type,
            status,
            cycle_started_at,
            cycle_ends_at,
            source,
            metadata
          ) VALUES ($1,$2,'LIFECYCLE','IN_USE',$3,$4,'backend.active_order_session.payment',$5::jsonb)
        `,
        [
          startMachineId,
          current.order_id,
          cycleStartedAt.toISOString(),
          cycleEndsAt.toISOString(),
          JSON.stringify({ paymentReference: parsed.data.paymentReference }),
        ],
      );

      const updatedSession = await client.query<ActiveOrderSessionRow>(
        `
          UPDATE active_order_sessions
          SET stage = 'PAID',
              payment_reference = $2,
              updated_at = NOW()
          WHERE id = $1
          RETURNING
            id,
            customer_name,
            customer_phone,
            load_size_kg,
            selected_services,
            wash_option,
            washer_machine_id,
            dryer_machine_id,
            ironing_machine_id,
            payment_method,
            stage,
            created_at,
            confirmed_by,
            order_id,
            payment_reference,
            is_active
        `,
        [current.id, parsed.data.paymentReference],
      );

      const row = updatedSession.rows[0];
      await writeAuditLog(client, {
        actorType: 'USER',
        actorUserId: authUserId ?? null,
        action: 'active_order_session.payment_completed',
        entityType: 'active_order_session',
        entityId: String(row.id),
        beforeState: serializeActiveOrderSession(current),
        afterState: serializeActiveOrderSession(row),
        metadata: {
          orderId: row.order_id,
          paymentReference: parsed.data.paymentReference,
        },
      });
      return row;
    });

    if (session == null) {
      response.status(404).json({
        error: 'not_found',
        detail: 'No active order session',
      });
      return;
    }

    response.json(serializeActiveOrderSession(session));
  } catch (error) {
    response.status(400).json({
      error: 'active_order_session_payment_failed',
      detail: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}

export async function clearActiveOrderSessionHandler(
  _request: Request,
  response: Response,
) {
  const authUserId = response.locals.authUserId as number | undefined;
  const cleared = await withTransaction(async (client) => {
    const sessionResult = await client.query<ActiveOrderSessionRow>(
      `
        SELECT
          id,
          customer_name,
          customer_phone,
          load_size_kg,
          selected_services,
          wash_option,
          washer_machine_id,
          dryer_machine_id,
          ironing_machine_id,
          payment_method,
          stage,
          created_at,
          confirmed_by,
          order_id,
          payment_reference,
          is_active
        FROM active_order_sessions
        WHERE is_active = TRUE
        ORDER BY updated_at DESC, id DESC
        LIMIT 1
        FOR UPDATE
      `,
    );
    if (sessionResult.rowCount === 0) {
      return null;
    }

    const current = sessionResult.rows[0];
    await client.query(
      `
        UPDATE active_order_sessions
        SET is_active = FALSE,
            updated_at = NOW()
        WHERE id = $1
      `,
      [current.id],
    );
    await writeAuditLog(client, {
      actorType: 'USER',
      actorUserId: authUserId ?? null,
      action: 'active_order_session.clear',
      entityType: 'active_order_session',
      entityId: String(current.id),
      beforeState: serializeActiveOrderSession(current),
      afterState: { isActive: false },
    });
    return current.id;
  });

  if (cleared == null) {
    response.status(404).json({
      error: 'not_found',
      detail: 'No active order session',
    });
    return;
  }

  response.status(204).send();
}
