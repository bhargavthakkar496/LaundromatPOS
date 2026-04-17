import type { Request, Response } from 'express';
import { z } from 'zod';

import { query, withTransaction } from '../db/transaction.js';
import { writeAuditLog } from '../services/audit.js';
import {
  serializeCustomer,
  serializeMachine,
  serializeOrder,
  serializeReservation,
} from '../services/serializers.js';

const phoneQuerySchema = z.object({
  phone: z.string().trim().min(1),
});

const saveWalkInCustomerSchema = z.object({
  fullName: z.string().trim().min(1),
  phone: z.string().trim().min(1),
  preferredWasherSizeKg: z.number().int().positive().nullable().optional(),
  preferredDetergentAddOn: z.string().trim().min(1).nullable().optional(),
  preferredDryerDurationMinutes: z.number().int().positive().nullable().optional(),
});

async function findCustomerByPhone(phone: string) {
  const result = await query<{
    id: number;
    full_name: string;
    phone: string;
    preferred_washer_size_kg: number | null;
    preferred_detergent_add_on: string | null;
    preferred_dryer_duration_minutes: number | null;
  }>(
    `
      SELECT
        id,
        full_name,
        phone,
        preferred_washer_size_kg,
        preferred_detergent_add_on,
        preferred_dryer_duration_minutes
      FROM customers
      WHERE phone = $1
      LIMIT 1
    `,
    [phone.trim()],
  );
  return result.rows[0] ?? null;
}

export async function getCustomerByPhoneHandler(
  request: Request,
  response: Response,
) {
  const parsed = phoneQuerySchema.safeParse(request.query);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_request',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const customer = await findCustomerByPhone(parsed.data.phone);
  if (customer == null) {
    response.status(404).json({
      error: 'not_found',
      detail: 'Customer not found',
    });
    return;
  }

  response.json(serializeCustomer(customer));
}

export async function saveWalkInCustomerHandler(
  request: Request,
  response: Response,
) {
  const parsed = saveWalkInCustomerSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_request',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;

  const savedCustomer = await withTransaction(async (client) => {
    const existingResult = await client.query<{
      id: number;
      full_name: string;
      phone: string;
      preferred_washer_size_kg: number | null;
      preferred_detergent_add_on: string | null;
      preferred_dryer_duration_minutes: number | null;
    }>(
      `
        SELECT
          id,
          full_name,
          phone,
          preferred_washer_size_kg,
          preferred_detergent_add_on,
          preferred_dryer_duration_minutes
        FROM customers
        WHERE phone = $1
        LIMIT 1
        FOR UPDATE
      `,
      [parsed.data.phone],
    );

    const before = existingResult.rows[0] ?? null;
    const savedResult = await client.query<{
      id: number;
      full_name: string;
      phone: string;
      preferred_washer_size_kg: number | null;
      preferred_detergent_add_on: string | null;
      preferred_dryer_duration_minutes: number | null;
    }>(
      `
        INSERT INTO customers (
          full_name,
          phone,
          preferred_washer_size_kg,
          preferred_detergent_add_on,
          preferred_dryer_duration_minutes,
          created_at,
          updated_at
        ) VALUES ($1,$2,$3,$4,$5,NOW(),NOW())
        ON CONFLICT (phone)
        DO UPDATE SET
          full_name = EXCLUDED.full_name,
          preferred_washer_size_kg = EXCLUDED.preferred_washer_size_kg,
          preferred_detergent_add_on = EXCLUDED.preferred_detergent_add_on,
          preferred_dryer_duration_minutes = EXCLUDED.preferred_dryer_duration_minutes,
          updated_at = NOW()
        RETURNING
          id,
          full_name,
          phone,
          preferred_washer_size_kg,
          preferred_detergent_add_on,
          preferred_dryer_duration_minutes
      `,
      [
        parsed.data.fullName,
        parsed.data.phone,
        parsed.data.preferredWasherSizeKg ?? null,
        parsed.data.preferredDetergentAddOn ?? null,
        parsed.data.preferredDryerDurationMinutes ?? null,
      ],
    );

    const after = savedResult.rows[0];
    await writeAuditLog(client, {
      actorType: 'USER',
      actorUserId: authUserId ?? null,
      action: 'customer.upsert_walk_in',
      entityType: 'customer',
      entityId: String(after.id),
      beforeState: before == null ? null : serializeCustomer(before),
      afterState: serializeCustomer(after),
    });
    return after;
  });

  response.json(serializeCustomer(savedCustomer));
}

export async function getCustomerProfileHandler(
  request: Request,
  response: Response,
) {
  const parsed = phoneQuerySchema.safeParse(request.query);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_request',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const customer = await findCustomerByPhone(parsed.data.phone);
  if (customer == null) {
    response.status(404).json({
      error: 'not_found',
      detail: 'Customer not found',
    });
    return;
  }

  const orderResult = await query<{
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
  }>(
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
      JOIN machines m ON m.id = o.machine_id
      LEFT JOIN machines d ON d.id = o.dryer_machine_id
      LEFT JOIN machines i ON i.id = o.ironing_machine_id
      WHERE o.customer_id = $1
      ORDER BY o.timestamp DESC
    `,
    [customer.id],
  );

  const reservationResult = await query<{
    id: number;
    machine_id: number;
    customer_id: number;
    start_time: Date | string;
    end_time: Date | string;
    status: string;
    created_at: Date | string;
    preferred_washer_size_kg: number | null;
    detergent_add_on: string | null;
    dryer_duration_minutes: number | null;
    machine_name: string;
    machine_type: string;
    machine_capacity_kg: number;
    machine_price: number | string;
    machine_status: string;
    machine_current_order_id: number | null;
    machine_cycle_started_at: Date | string | null;
    machine_cycle_ends_at: Date | string | null;
  }>(
    `
      SELECT
        r.id,
        r.machine_id,
        r.customer_id,
        r.start_time,
        r.end_time,
        r.status,
        r.created_at,
        r.preferred_washer_size_kg,
        r.detergent_add_on,
        r.dryer_duration_minutes,
        m.name AS machine_name,
        m.type AS machine_type,
        m.capacity_kg AS machine_capacity_kg,
        m.price AS machine_price,
        m.status AS machine_status,
        m.current_order_id AS machine_current_order_id,
        m.cycle_started_at AS machine_cycle_started_at,
        m.cycle_ends_at AS machine_cycle_ends_at
      FROM machine_reservations r
      JOIN machines m ON m.id = r.machine_id
      WHERE r.customer_id = $1
        AND r.status = 'BOOKED'
        AND r.end_time > NOW()
      ORDER BY r.start_time ASC
    `,
    [customer.id],
  );

  const favoriteCounts = new Map<number, { count: number; machine: ReturnType<typeof serializeMachine> }>();

  const orders = orderResult.rows.map((row: (typeof orderResult.rows)[number]) => {
    const machine = serializeMachine({
      id: row.machine_id,
      name: row.machine_name,
      type: row.machine_type,
      capacity_kg: row.machine_capacity_kg,
      price: row.machine_price,
      status: row.machine_status,
      current_order_id: row.machine_current_order_id,
      cycle_started_at: row.machine_cycle_started_at,
      cycle_ends_at: row.machine_cycle_ends_at,
    });
    const dryerMachine = row.dryer_machine_id == null
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
          });

    const existing = favoriteCounts.get(machine.id);
    if (existing == null) {
      favoriteCounts.set(machine.id, { count: 1, machine });
    } else {
      existing.count += 1;
    }

    return {
      order: serializeOrder(row),
      machine,
      customer: serializeCustomer(customer),
      dryerMachine,
      ironingMachine: row.ironing_machine_id == null
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
  });

  const upcomingReservations = reservationResult.rows.map(
    (row: (typeof reservationResult.rows)[number]) => ({
    reservation: serializeReservation(row),
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
    customer: serializeCustomer(customer),
  }),
  );

  const favoriteMachines = Array.from(favoriteCounts.values())
    .sort((left, right) => right.count - left.count)
    .slice(0, 3)
    .map((entry) => ({
      machine: entry.machine,
      usageCount: entry.count,
    }));

  const totalSpent = orders.reduce((sum: number, item: (typeof orders)[number]) => {
    if (item.order.paymentStatus === 'PAID') {
      return sum + Number(item.order.amount);
    }
    return sum;
  }, 0);

  response.json({
    customer: serializeCustomer(customer),
    orders,
    totalSpent,
    totalVisits: orders.length,
    favoriteMachines,
    upcomingReservations,
  });
}
