import type { Request, Response } from 'express';
import { z } from 'zod';

import { withTransaction } from '../db/transaction.js';
import { writeAuditLog } from '../services/audit.js';
import { serializeReservation } from '../services/serializers.js';

type ReservationRow = {
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
};

const createReservationSchema = z.object({
  machineId: z.number().int().positive(),
  customerId: z.number().int().positive(),
  startTime: z.string().datetime(),
  endTime: z.string().datetime(),
  preferredWasherSizeKg: z.number().int().positive().nullable().optional(),
  detergentAddOn: z.string().trim().min(1).nullable().optional(),
  dryerDurationMinutes: z.number().int().positive().nullable().optional(),
});

export async function createReservationHandler(
  request: Request,
  response: Response,
) {
  const parsed = createReservationSchema.safeParse(request.body);
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

  const authUserId = response.locals.authUserId as number | undefined;

  try {
    const reservation = await withTransaction(async (client) => {
      const machineResult = await client.query<{
        id: number;
        status: string;
        cycle_ends_at: Date | string | null;
      }>(
        `
          SELECT id, status, cycle_ends_at
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
      if (machine.status === 'MAINTENANCE') {
        throw new Error('Machine is in maintenance');
      }
      if (
        machine.status === 'IN_USE' &&
        machine.cycle_ends_at != null &&
        new Date(machine.cycle_ends_at) > startTime
      ) {
        throw new Error('Machine is still in use during the requested window');
      }

      const customerResult = await client.query<{ id: number }>(
        `SELECT id FROM customers WHERE id = $1`,
        [parsed.data.customerId],
      );
      if (customerResult.rowCount === 0) {
        throw new Error('Customer not found');
      }

      const overlapResult = await client.query<{ id: number }>(
        `
          SELECT id
          FROM machine_reservations
          WHERE machine_id = $1
            AND status = 'BOOKED'
            AND start_time < $3::timestamptz
            AND end_time > $2::timestamptz
          LIMIT 1
        `,
        [parsed.data.machineId, startTime.toISOString(), endTime.toISOString()],
      );
      if ((overlapResult.rowCount ?? 0) > 0) {
        throw new Error('Reservation window conflicts with an existing booking');
      }

      const inserted = await client.query<ReservationRow>(
        `
          INSERT INTO machine_reservations (
            machine_id,
            customer_id,
            start_time,
            end_time,
            status,
            created_at,
            preferred_washer_size_kg,
            detergent_add_on,
            dryer_duration_minutes
          ) VALUES ($1,$2,$3,$4,'BOOKED',NOW(),$5,$6,$7)
          RETURNING
            id,
            machine_id,
            customer_id,
            start_time,
            end_time,
            status,
            created_at,
            preferred_washer_size_kg,
            detergent_add_on,
            dryer_duration_minutes
        `,
        [
          parsed.data.machineId,
          parsed.data.customerId,
          startTime.toISOString(),
          endTime.toISOString(),
          parsed.data.preferredWasherSizeKg ?? null,
          parsed.data.detergentAddOn ?? null,
          parsed.data.dryerDurationMinutes ?? null,
        ],
      );
      const row = inserted.rows[0];

      await writeAuditLog(client, {
        actorType: 'USER',
        actorUserId: authUserId ?? null,
        action: 'reservation.create',
        entityType: 'reservation',
        entityId: String(row.id),
        afterState: serializeReservation(row),
      });

      return row;
    });

    response.json(serializeReservation(reservation));
  } catch (error) {
    response.status(400).json({
      error: 'reservation_create_failed',
      detail: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}
