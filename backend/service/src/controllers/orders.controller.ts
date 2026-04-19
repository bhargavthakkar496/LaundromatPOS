import type { Request, Response } from 'express';
import { z } from 'zod';

import { query, withTransaction } from '../db/transaction.js';
import { writeAuditLog } from '../services/audit.js';
import { calculatePricingQuote } from '../services/pricing.service.js';
import { generateReference } from '../services/security.js';
import {
  serializeCustomer,
  serializeMachine,
  serializeOrder,
} from '../services/serializers.js';

type OrderRow = {
  id: number;
  machine_id: number;
  customer_id: number;
  created_by_user_id: number | null;
  service_type: string;
  selected_services: string[] | null;
  amount: number | string;
  status: string;
  payment_method: string;
  payment_status: string;
  payment_reference: string;
  timestamp: Date | string;
  load_size_kg: number | null;
  wash_option: string | null;
  dryer_machine_id: number | null;
  ironing_machine_id: number | null;
};

type MachineRow = {
  id: number;
  name: string;
  type: string;
  capacity_kg: number;
  price: number | string;
  status: string;
  current_order_id: number | null;
  cycle_started_at: Date | string | null;
  cycle_ends_at: Date | string | null;
};

type CustomerRow = {
  id: number;
  full_name: string;
  phone: string;
  preferred_washer_size_kg: number | null;
  preferred_detergent_add_on: string | null;
  preferred_dryer_duration_minutes: number | null;
};

type OrderHistoryRow = OrderRow & {
  customer_full_name: string;
  customer_phone: string;
  customer_preferred_washer_size_kg: number | null;
  customer_preferred_detergent_add_on: string | null;
  customer_preferred_dryer_duration_minutes: number | null;
  machine_name: string;
  machine_type: string;
  machine_capacity_kg: number;
  machine_price: number | string;
  machine_status: string;
  machine_current_order_id: number | null;
  machine_cycle_started_at: Date | string | null;
  machine_cycle_ends_at: Date | string | null;
  dryer_name: string | null;
  dryer_type: string | null;
  dryer_capacity_kg: number | null;
  dryer_price: number | string | null;
  dryer_status: string | null;
  dryer_current_order_id: number | null;
  dryer_cycle_started_at: Date | string | null;
  dryer_cycle_ends_at: Date | string | null;
  ironing_name: string | null;
  ironing_type: string | null;
  ironing_capacity_kg: number | null;
  ironing_price: number | string | null;
  ironing_status: string | null;
  ironing_current_order_id: number | null;
  ironing_cycle_started_at: Date | string | null;
  ironing_cycle_ends_at: Date | string | null;
};

const orderIdSchema = z.coerce.number().int().positive();
const createPaidOrderSchema = z.object({
  machineId: z.number().int().positive(),
  customerId: z.number().int().positive(),
  createdByUserId: z.number().int().positive().nullable().optional(),
  paymentMethod: z.string().trim().min(1),
  referencePrefix: z.string().trim().min(1).optional(),
  paymentReference: z.string().trim().min(1).nullable().optional(),
});

const createManualOrderSchema = z.object({
  customerName: z.string().trim().min(1),
  customerPhone: z.string().trim().min(1),
  loadSizeKg: z.number().int().positive(),
  selectedServices: z.array(z.enum(['Washing', 'Drying', 'Ironing'])).min(1),
  washOption: z.string().trim().min(1).nullable().optional(),
  washerMachineId: z.number().int().positive().nullable().optional(),
  dryerMachineId: z.number().int().positive().nullable().optional(),
  ironingMachineId: z.number().int().positive().nullable().optional(),
  orderStatus: z.enum(['BOOKED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']),
  paymentMethod: z.string().trim().min(1),
  createdByUserId: z.number().int().positive().nullable().optional(),
});

function cycleDurationMinutes(machineType: string) {
  if (machineType.toLowerCase() === 'washer') {
    return 35;
  }
  if (machineType.toLowerCase() === 'dryer') {
    return 25;
  }
  return 20;
}

function primaryMachineId(order: {
  washerMachineId?: number | null;
  dryerMachineId?: number | null;
  ironingMachineId?: number | null;
}) {
  return order.washerMachineId ?? order.dryerMachineId ?? order.ironingMachineId;
}

function validateSelectedServices(order: {
  selectedServices: string[];
  washOption?: string | null;
  washerMachineId?: number | null;
  dryerMachineId?: number | null;
  ironingMachineId?: number | null;
}) {
  if (
    order.selectedServices.includes('Washing') &&
    (order.washerMachineId == null || order.washOption == null)
  ) {
    return 'Washing requires both a wash option and washer assignment';
  }
  if (
    order.selectedServices.includes('Drying') &&
    order.dryerMachineId == null
  ) {
    return 'Drying requires a dryer assignment';
  }
  if (
    order.selectedServices.includes('Ironing') &&
    order.ironingMachineId == null
  ) {
    return 'Ironing requires an ironing station assignment';
  }
  return null;
}

async function fetchOrderHistoryRows(orderId?: number) {
  const values: unknown[] = [];
  let whereClause = '';
  if (orderId != null) {
    whereClause = 'WHERE o.id = $1';
    values.push(orderId);
  }

  return query<OrderHistoryRow>(
    `
      SELECT
        o.id,
        o.machine_id,
        o.customer_id,
        o.created_by_user_id,
        o.service_type,
        o.selected_services,
        o.amount,
        o.status,
        o.payment_method,
        o.payment_status,
        o.payment_reference,
        o.timestamp,
        o.load_size_kg,
        o.wash_option,
        o.dryer_machine_id,
        o.ironing_machine_id,
        c.full_name AS customer_full_name,
        c.phone AS customer_phone,
        c.preferred_washer_size_kg AS customer_preferred_washer_size_kg,
        c.preferred_detergent_add_on AS customer_preferred_detergent_add_on,
        c.preferred_dryer_duration_minutes AS customer_preferred_dryer_duration_minutes,
        m.name AS machine_name,
        m.type AS machine_type,
        m.capacity_kg AS machine_capacity_kg,
        m.price AS machine_price,
        m.status AS machine_status,
        m.current_order_id AS machine_current_order_id,
        m.cycle_started_at AS machine_cycle_started_at,
        m.cycle_ends_at AS machine_cycle_ends_at,
        d.name AS dryer_name,
        d.type AS dryer_type,
        d.capacity_kg AS dryer_capacity_kg,
        d.price AS dryer_price,
        d.status AS dryer_status,
        d.current_order_id AS dryer_current_order_id,
        d.cycle_started_at AS dryer_cycle_started_at,
        d.cycle_ends_at AS dryer_cycle_ends_at,
        i.name AS ironing_name,
        i.type AS ironing_type,
        i.capacity_kg AS ironing_capacity_kg,
        i.price AS ironing_price,
        i.status AS ironing_status,
        i.current_order_id AS ironing_current_order_id,
        i.cycle_started_at AS ironing_cycle_started_at,
        i.cycle_ends_at AS ironing_cycle_ends_at
      FROM orders o
      JOIN customers c ON c.id = o.customer_id
      JOIN machines m ON m.id = o.machine_id
      LEFT JOIN machines d ON d.id = o.dryer_machine_id
      LEFT JOIN machines i ON i.id = o.ironing_machine_id
      ${whereClause}
      ORDER BY o.timestamp DESC
    `,
    values,
  );
}

function serializeOrderHistoryItem(row: OrderHistoryRow) {
  return {
    order: serializeOrder(row),
    customer: serializeCustomer({
      id: row.customer_id,
      full_name: row.customer_full_name,
      phone: row.customer_phone,
      preferred_washer_size_kg: row.customer_preferred_washer_size_kg,
      preferred_detergent_add_on: row.customer_preferred_detergent_add_on,
      preferred_dryer_duration_minutes:
        row.customer_preferred_dryer_duration_minutes,
    }),
    machine: serializeMachine({
      id: row.machine_id,
      name: row.machine_name,
      type: row.machine_type,
      capacity_kg: row.machine_capacity_kg,
      price: row.machine_price,
      status: row.machine_status,
      current_order_id: row.machine_current_order_id,
      cycle_started_at: row.machine_cycle_started_at,
      cycle_ends_at: row.machine_cycle_ends_at,
    }),
    dryerMachine:
      row.dryer_machine_id == null
        ? null
        : serializeMachine({
            id: row.dryer_machine_id,
            name: row.dryer_name ?? 'Dryer',
            type: row.dryer_type ?? 'Dryer',
            capacity_kg: row.dryer_capacity_kg ?? 0,
            price: row.dryer_price ?? 0,
            status: row.dryer_status ?? 'AVAILABLE',
            current_order_id: row.dryer_current_order_id,
            cycle_started_at: row.dryer_cycle_started_at,
            cycle_ends_at: row.dryer_cycle_ends_at,
          }),
    ironingMachine:
      row.ironing_machine_id == null
        ? null
        : serializeMachine({
            id: row.ironing_machine_id,
            name: row.ironing_name ?? 'Ironing Station',
            type: row.ironing_type ?? 'Ironing Station',
            capacity_kg: row.ironing_capacity_kg ?? 0,
            price: row.ironing_price ?? 0,
            status: row.ironing_status ?? 'AVAILABLE',
            current_order_id: row.ironing_current_order_id,
            cycle_started_at: row.ironing_cycle_started_at,
            cycle_ends_at: row.ironing_cycle_ends_at,
          }),
  };
}

export async function listOrderHistoryHandler(
  _request: Request,
  response: Response,
) {
  const result = await fetchOrderHistoryRows();
  response.json(result.rows.map((row) => serializeOrderHistoryItem(row)));
}

export async function getOrderHistoryItemHandler(
  request: Request,
  response: Response,
) {
  const parsedId = orderIdSchema.safeParse(request.params.orderId);
  if (!parsedId.success) {
    response.status(400).json({ error: 'invalid_order_id' });
    return;
  }

  const result = await fetchOrderHistoryRows(parsedId.data);
  if (result.rowCount === 0) {
    response.status(404).json({
      error: 'not_found',
      detail: 'Order not found',
    });
    return;
  }

  response.json(serializeOrderHistoryItem(result.rows[0]));
}

export async function createPaidOrderHandler(
  request: Request,
  response: Response,
) {
  const parsed = createPaidOrderSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_request',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;

  try {
    const created = await withTransaction(async (client) => {
      const machineResult = await client.query<MachineRow>(
        `
          SELECT id, name, type, capacity_kg, price, status, current_order_id, cycle_started_at, cycle_ends_at
          FROM machines
          WHERE id = $1
          FOR UPDATE
        `,
        [parsed.data.machineId],
      );
      if (machineResult.rowCount === 0) {
        throw new Error('Machine not found');
      }
      const machine = machineResult.rows[0];
      if (machine.status !== 'AVAILABLE') {
        throw new Error('Machine is not available');
      }

      const customerResult = await client.query<CustomerRow>(
        `
          SELECT id, full_name, phone, preferred_washer_size_kg, preferred_detergent_add_on, preferred_dryer_duration_minutes
          FROM customers
          WHERE id = $1
        `,
        [parsed.data.customerId],
      );
      if (customerResult.rowCount === 0) {
        throw new Error('Customer not found');
      }

      const paymentReference =
        parsed.data.paymentReference ??
        generateReference(parsed.data.referencePrefix ?? 'POS');
      const createdByUserId = parsed.data.createdByUserId ?? authUserId ?? null;

      const quote = await calculatePricingQuote(client, {
        machineIds: [machine.id],
        selectedServices: [
          machine.type == 'Dryer'
            ? 'Drying'
            : machine.type == 'Ironing Station'
              ? 'Ironing'
              : 'Washing',
        ],
      });

      const insertedOrder = await client.query<OrderRow>(
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
            ironing_machine_id
          ) VALUES ($1,$2,$3,$4,$5::text[],$6,'IN_PROGRESS',$7,'PAID',$8,NOW(),$9,'Standard Wash',NULL)
          RETURNING
            id, machine_id, customer_id, created_by_user_id, service_type, amount,
            status, payment_method, payment_status, payment_reference, timestamp,
            selected_services, load_size_kg, wash_option, dryer_machine_id, ironing_machine_id
        `,
        [
          machine.id,
          parsed.data.customerId,
          createdByUserId,
          machine.type.toUpperCase(),
          [machine.type == 'Dryer' ? 'Drying' : machine.type == 'Ironing Station' ? 'Ironing' : 'Washing'],
          quote.finalTotal,
          parsed.data.paymentMethod,
          paymentReference,
          machine.capacity_kg,
        ],
      );
      const order = insertedOrder.rows[0];
      const cycleStartedAt = new Date();
      const cycleEndsAt = new Date(
        cycleStartedAt.getTime() + cycleDurationMinutes(machine.type) * 60_000,
      );

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
        [order.id, order.amount, parsed.data.paymentMethod, paymentReference],
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
          machine.id,
          order.id,
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
          ) VALUES ($1,$2,'LIFECYCLE','IN_USE',$3,$4,'backend.order.create_paid',$5::jsonb)
        `,
        [
          machine.id,
          order.id,
          cycleStartedAt.toISOString(),
          cycleEndsAt.toISOString(),
          JSON.stringify({ paymentReference }),
        ],
      );

      await writeAuditLog(client, {
        actorType: 'USER',
        actorUserId: authUserId ?? null,
        action: 'order.create_paid',
        entityType: 'order',
        entityId: String(order.id),
        afterState: serializeOrder(order),
        metadata: {
          machineId: machine.id,
          customerId: parsed.data.customerId,
          paymentReference,
        },
      });

      return order;
    });

    response.json(serializeOrder(created));
  } catch (error) {
    response.status(400).json({
      error: 'order_create_failed',
      detail: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}

export async function createManualOrderHandler(
  request: Request,
  response: Response,
) {
  const parsed = createManualOrderSchema.safeParse(request.body);
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

  try {
    const created = await withTransaction(async (client) => {
      const machineIds = [
        parsed.data.washerMachineId,
        parsed.data.dryerMachineId,
        parsed.data.ironingMachineId,
      ].filter((value): value is number => value != null);
      const machineResults = await client.query<MachineRow>(
        `
          SELECT id, name, type, capacity_kg, price, status, current_order_id, cycle_started_at, cycle_ends_at
          FROM machines
          WHERE id = ANY($1::bigint[])
        `,
        [machineIds],
      );
      if (machineResults.rowCount !== machineIds.length) {
        throw new Error('One or more assigned machines were not found');
      }

      const customerResult = await client.query<CustomerRow>(
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
          RETURNING
            id, full_name, phone, preferred_washer_size_kg, preferred_detergent_add_on, preferred_dryer_duration_minutes
        `,
        [parsed.data.customerName, parsed.data.customerPhone, parsed.data.loadSizeKg],
      );
      const customer = customerResult.rows[0];
      const paymentReference = generateReference('ORD');
      const createdByUserId = parsed.data.createdByUserId ?? authUserId ?? null;
      const paymentStatus =
        parsed.data.orderStatus === 'BOOKED' ? 'PENDING' : 'PAID';
      const quote = await calculatePricingQuote(client, {
        machineIds,
        selectedServices: parsed.data.selectedServices,
      });
      const totalAmount = quote.finalTotal;
      const primaryMachine = primaryMachineId(parsed.data);
      if (primaryMachine == null) {
        throw new Error('At least one service machine assignment is required');
      }

      const insertedOrder = await client.query<OrderRow>(
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
          ) VALUES ($1,$2,$3,$4,$5::text[],$6,$7,$8,$9,$10,NOW(),$11,$12,$13,$14)
          RETURNING
            id, machine_id, customer_id, created_by_user_id, service_type, amount,
            status, payment_method, payment_status, payment_reference, timestamp,
            selected_services, load_size_kg, wash_option, dryer_machine_id, ironing_machine_id
        `,
        [
          primaryMachine,
          customer.id,
          createdByUserId,
          parsed.data.selectedServices.map((item) => item.toUpperCase()).join('+'),
          parsed.data.selectedServices,
          totalAmount,
          parsed.data.orderStatus,
          parsed.data.paymentMethod,
          paymentStatus,
          paymentReference,
          parsed.data.loadSizeKg,
          parsed.data.washOption ?? null,
          parsed.data.dryerMachineId ?? null,
          parsed.data.ironingMachineId ?? null,
        ],
      );
      const order = insertedOrder.rows[0];

      if (parsed.data.orderStatus === 'IN_PROGRESS') {
        const startMachine =
          machineResults.rows.find((item) => item.id === primaryMachine) ??
          machineResults.rows[0];
        const cycleStartedAt = new Date();
        const cycleEndsAt = new Date(
          cycleStartedAt.getTime() +
            cycleDurationMinutes(startMachine.type) * 60_000,
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
            startMachine.id,
            order.id,
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
            ) VALUES ($1,$2,'LIFECYCLE','IN_USE',$3,$4,'backend.order.create_manual',$5::jsonb)
          `,
          [
            startMachine.id,
            order.id,
            cycleStartedAt.toISOString(),
            cycleEndsAt.toISOString(),
            JSON.stringify({ paymentReference }),
          ],
        );
      }

      await writeAuditLog(client, {
        actorType: 'USER',
        actorUserId: authUserId ?? null,
        action: 'order.create_manual',
        entityType: 'order',
        entityId: String(order.id),
        afterState: serializeOrder(order),
        metadata: {
          customerId: customer.id,
          washerMachineId: parsed.data.washerMachineId ?? null,
          dryerMachineId: parsed.data.dryerMachineId ?? null,
          ironingMachineId: parsed.data.ironingMachineId ?? null,
          selectedServices: parsed.data.selectedServices,
        },
      });

      return order;
    });

    response.json(serializeOrder(created));
  } catch (error) {
    response.status(400).json({
      error: 'order_create_failed',
      detail: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}

export async function refundOrderHandler(request: Request, response: Response) {
  const parsedId = orderIdSchema.safeParse(request.params.orderId);
  if (!parsedId.success) {
    response.status(400).json({ error: 'invalid_order_id' });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;
  const updated = await withTransaction(async (client) => {
    const existing = await client.query<OrderRow>(
      `
        SELECT
          id, machine_id, customer_id, created_by_user_id, service_type, amount,
          status, payment_method, payment_status, payment_reference, timestamp,
          selected_services, load_size_kg, wash_option, dryer_machine_id, ironing_machine_id
        FROM orders
        WHERE id = $1
        FOR UPDATE
      `,
      [parsedId.data],
    );
    if (existing.rowCount === 0) {
      return null;
    }

    const before = existing.rows[0];
    const result = await client.query<OrderRow>(
      `
        UPDATE orders
        SET payment_status = 'REFUNDED',
            updated_at = NOW()
        WHERE id = $1
        RETURNING
          id, machine_id, customer_id, created_by_user_id, service_type, amount,
          status, payment_method, payment_status, payment_reference, timestamp,
          selected_services, load_size_kg, wash_option, dryer_machine_id, ironing_machine_id
      `,
      [parsedId.data],
    );
    const after = result.rows[0];

    await client.query(
      `
        UPDATE payments
        SET payment_status = 'REFUNDED',
            settled_at = NOW()
        WHERE order_id = $1
      `,
      [parsedId.data],
    );

    await writeAuditLog(client, {
      actorType: 'USER',
      actorUserId: authUserId ?? null,
      action: 'order.refund_processed',
      entityType: 'order',
      entityId: String(parsedId.data),
      beforeState: serializeOrder(before),
      afterState: serializeOrder(after),
    });

    return after;
  });

  if (updated == null) {
    response.status(404).json({
      error: 'not_found',
      detail: 'Order not found',
    });
    return;
  }

  response.json(serializeOrder(updated));
}
