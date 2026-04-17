import type { Request, Response } from 'express';
import { z } from 'zod';

import { query, withTransaction } from '../db/transaction.js';
import { writeAuditLog } from '../services/audit.js';
import { serializeMachine } from '../services/serializers.js';

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

const machineIdSchema = z.coerce.number().int().positive();
const machineListQuerySchema = z.object({
  status: z
    .enum(['AVAILABLE', 'MAINTENANCE', 'IN_USE', 'READY_FOR_PICKUP'])
    .optional(),
});
const reservableQuerySchema = z.object({
  machineType: z.string().trim().min(1),
  startTime: z.string().datetime(),
  endTime: z.string().datetime(),
});

async function fetchMachineById(machineId: number) {
  const result = await query<MachineRow>(
    `
      SELECT
        id,
        name,
        type,
        capacity_kg,
        price,
        status,
        current_order_id,
        cycle_started_at,
        cycle_ends_at
      FROM machines
      WHERE id = $1
    `,
    [machineId],
  );
  return result.rows[0] ?? null;
}

export async function listMachinesHandler(request: Request, response: Response) {
  const parsed = machineListQuerySchema.safeParse(request.query);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_request',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const values: unknown[] = [];
  let whereClause = '';
  if (parsed.data.status != null) {
    whereClause = 'WHERE status = $1';
    values.push(parsed.data.status);
  }

  const result = await query<MachineRow>(
    `
      SELECT
        id,
        name,
        type,
        capacity_kg,
        price,
        status,
        current_order_id,
        cycle_started_at,
        cycle_ends_at
      FROM machines
      ${whereClause}
      ORDER BY id ASC
    `,
    values,
  );

  response.json(
    result.rows.map((row) => serializeMachine(row)),
  );
}

export async function getMachineHandler(request: Request, response: Response) {
  const parsedId = machineIdSchema.safeParse(request.params.machineId);
  if (!parsedId.success) {
    response.status(400).json({
      error: 'invalid_machine_id',
    });
    return;
  }

  const machine = await fetchMachineById(parsedId.data);
  if (machine == null) {
    response.status(404).json({
      error: 'not_found',
      detail: 'Machine not found',
    });
    return;
  }

  response.json(serializeMachine(machine));
}

export async function listReservableMachinesHandler(
  request: Request,
  response: Response,
) {
  const parsed = reservableQuerySchema.safeParse(request.query);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_request',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const startTime = new Date(parsed.data.startTime);
  const endTime = new Date(parsed.data.endTime);
  if (!(startTime < endTime)) {
    response.status(400).json({
      error: 'invalid_time_window',
      detail: 'startTime must be before endTime',
    });
    return;
  }

  const result = await query<MachineRow>(
    `
      SELECT
        m.id,
        m.name,
        m.type,
        m.capacity_kg,
        m.price,
        m.status,
        m.current_order_id,
        m.cycle_started_at,
        m.cycle_ends_at
      FROM machines m
      WHERE LOWER(m.type) = LOWER($1)
        AND m.status != 'MAINTENANCE'
        AND NOT (
          m.status = 'IN_USE'
          AND m.cycle_ends_at IS NOT NULL
          AND m.cycle_ends_at > $2::timestamptz
        )
        AND NOT EXISTS (
          SELECT 1
          FROM machine_reservations r
          WHERE r.machine_id = m.id
            AND r.status = 'BOOKED'
            AND r.start_time < $3::timestamptz
            AND r.end_time > $2::timestamptz
        )
      ORDER BY m.id ASC
    `,
    [parsed.data.machineType, startTime.toISOString(), endTime.toISOString()],
  );

  response.json(
    result.rows.map((row) => serializeMachine(row)),
  );
}

export async function markMachinePickupHandler(
  request: Request,
  response: Response,
) {
  const parsedId = machineIdSchema.safeParse(request.params.machineId);
  if (!parsedId.success) {
    response.status(400).json({
      error: 'invalid_machine_id',
    });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;

  const updatedMachine = await withTransaction(async (client) => {
    const machineResult = await client.query<MachineRow>(
      `
        SELECT
          id,
          name,
          type,
          capacity_kg,
          price,
          status,
          current_order_id,
          cycle_started_at,
          cycle_ends_at
        FROM machines
        WHERE id = $1
        FOR UPDATE
      `,
      [parsedId.data],
    );

    if (machineResult.rowCount === 0) {
      return null;
    }

    const before = machineResult.rows[0];
    if (before.current_order_id != null) {
      await client.query(
        `
          UPDATE orders
          SET status = CASE
              WHEN status = 'IN_PROGRESS' THEN 'COMPLETED'::order_status
              ELSE status
            END,
            completed_at = CASE
              WHEN completed_at IS NULL THEN NOW()
              ELSE completed_at
            END,
            updated_at = NOW()
          WHERE id = $1
        `,
        [before.current_order_id],
      );
    }

    const updateResult = await client.query<MachineRow>(
      `
        UPDATE machines
        SET status = 'AVAILABLE',
            current_order_id = NULL,
            cycle_started_at = NULL,
            cycle_ends_at = NULL,
            updated_at = NOW()
        WHERE id = $1
        RETURNING
          id,
          name,
          type,
          capacity_kg,
          price,
          status,
          current_order_id,
          cycle_started_at,
          cycle_ends_at
      `,
      [parsedId.data],
    );

    const after = updateResult.rows[0];
    await writeAuditLog(client, {
      actorType: 'USER',
      actorUserId: authUserId ?? null,
      action: 'machine.pickup',
      entityType: 'machine',
      entityId: String(parsedId.data),
      beforeState: serializeMachine(before),
      afterState: serializeMachine(after),
    });

    return after;
  });

  if (updatedMachine == null) {
    response.status(404).json({
      error: 'not_found',
      detail: 'Machine not found',
    });
    return;
  }

  response.json(serializeMachine(updatedMachine));
}
