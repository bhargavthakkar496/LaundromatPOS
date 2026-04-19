import type { Request, Response } from 'express';
import { z } from 'zod';

import { query, withTransaction } from '../db/transaction.js';
import { writeAuditLog } from '../services/audit.js';
import {
  serializeMachine,
  serializeMaintenanceRecord,
} from '../services/serializers.js';

type MaintenanceRecordRow = {
  id: number;
  machine_id: number;
  issue_title: string;
  issue_description: string | null;
  priority: string;
  status: string;
  reported_by_name: string | null;
  started_by_name: string | null;
  completed_by_name: string | null;
  reported_at: Date | string;
  started_at: Date | string | null;
  completed_at: Date | string | null;
  resolution_notes: string | null;
  created_at: Date | string;
  updated_at: Date | string;
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

const maintenanceStatusSchema = z.enum(['MARKED', 'IN_PROGRESS', 'COMPLETED']);
const maintenancePrioritySchema = z.enum(['LOW', 'MEDIUM', 'HIGH']);
const machineIdSchema = z.coerce.number().int().positive();
const recordIdSchema = z.coerce.number().int().positive();

const maintenanceListQuerySchema = z.object({
  status: maintenanceStatusSchema.optional(),
});

const createMaintenanceRecordSchema = z.object({
  machineId: z.coerce.number().int().positive(),
  issueTitle: z.string().trim().min(1).max(160),
  issueDescription: z.string().trim().max(1000).nullish(),
  priority: maintenancePrioritySchema.default('MEDIUM'),
  reportedByName: z.string().trim().min(1).max(120).nullish(),
});

const startMaintenanceRecordSchema = z.object({
  startedByName: z.string().trim().min(1).max(120).nullish(),
});

const completeMaintenanceRecordSchema = z.object({
  completedByName: z.string().trim().min(1).max(120).nullish(),
  resolutionNotes: z.string().trim().min(1).max(1000).nullish(),
});

async function fetchMaintenanceRecordById(recordId: number) {
  const result = await query<MaintenanceRecordRow>(
    `
      SELECT
        id,
        machine_id,
        issue_title,
        issue_description,
        priority,
        status,
        reported_by_name,
        started_by_name,
        completed_by_name,
        reported_at,
        started_at,
        completed_at,
        resolution_notes,
        created_at,
        updated_at
      FROM maintenance_records
      WHERE id = $1
    `,
    [recordId],
  );
  return result.rows[0] ?? null;
}

export async function listMaintenanceRecordsHandler(
  request: Request,
  response: Response,
) {
  const parsed = maintenanceListQuerySchema.safeParse(request.query);
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

  const result = await query<MaintenanceRecordRow>(
    `
      SELECT
        id,
        machine_id,
        issue_title,
        issue_description,
        priority,
        status,
        reported_by_name,
        started_by_name,
        completed_by_name,
        reported_at,
        started_at,
        completed_at,
        resolution_notes,
        created_at,
        updated_at
      FROM maintenance_records
      ${whereClause}
      ORDER BY
        CASE status
          WHEN 'IN_PROGRESS' THEN 0
          WHEN 'MARKED' THEN 1
          ELSE 2
        END,
        COALESCE(started_at, reported_at) DESC,
        id DESC
    `,
    values,
  );

  response.json(result.rows.map((row) => serializeMaintenanceRecord(row)));
}

export async function createMaintenanceRecordHandler(
  request: Request,
  response: Response,
) {
  const parsed = createMaintenanceRecordSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_request',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;

  const created = await withTransaction(async (client) => {
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
      [parsed.data.machineId],
    );

    if (machineResult.rowCount === 0) {
      return { type: 'not_found' as const };
    }

    const machineBefore = machineResult.rows[0];
    if (machineBefore.status !== 'AVAILABLE') {
      return { type: 'invalid_machine_status' as const, status: machineBefore.status };
    }

    const activeRecordResult = await client.query<{ id: number }>(
      `
        SELECT id
        FROM maintenance_records
        WHERE machine_id = $1
          AND status IN ('MARKED', 'IN_PROGRESS')
        LIMIT 1
      `,
      [parsed.data.machineId],
    );
    if ((activeRecordResult.rowCount ?? 0) > 0) {
      return { type: 'duplicate_active_record' as const };
    }

    await client.query(
      `
        UPDATE machines
        SET status = 'MAINTENANCE',
            updated_at = NOW()
        WHERE id = $1
      `,
      [parsed.data.machineId],
    );

    const insertResult = await client.query<MaintenanceRecordRow>(
      `
        INSERT INTO maintenance_records (
          machine_id,
          issue_title,
          issue_description,
          priority,
          status,
          reported_by_name,
          reported_at,
          created_at,
          updated_at
        ) VALUES ($1, $2, $3, $4, 'MARKED', $5, NOW(), NOW(), NOW())
        RETURNING
          id,
          machine_id,
          issue_title,
          issue_description,
          priority,
          status,
          reported_by_name,
          started_by_name,
          completed_by_name,
          reported_at,
          started_at,
          completed_at,
          resolution_notes,
          created_at,
          updated_at
      `,
      [
        parsed.data.machineId,
        parsed.data.issueTitle,
        parsed.data.issueDescription ?? null,
        parsed.data.priority,
        parsed.data.reportedByName ?? null,
      ],
    );

    const machineAfterResult = await client.query<MachineRow>(
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
      [parsed.data.machineId],
    );

    await writeAuditLog(client, {
      actorType: 'USER',
      actorUserId: authUserId ?? null,
      action: 'maintenance.record_created',
      entityType: 'maintenance_record',
      entityId: String(insertResult.rows[0].id),
      afterState: serializeMaintenanceRecord(insertResult.rows[0]),
      metadata: {
        machine: {
          before: serializeMachine(machineBefore),
          after: serializeMachine(machineAfterResult.rows[0]),
        },
      },
    });

    return { type: 'created' as const, record: insertResult.rows[0] };
  });

  if (created.type === 'not_found') {
    response.status(404).json({ error: 'not_found', detail: 'Machine not found' });
    return;
  }
  if (created.type === 'invalid_machine_status') {
    response.status(409).json({
      error: 'invalid_machine_status',
      detail: `Only available machines can be marked for maintenance. Current status: ${created.status}`,
    });
    return;
  }
  if (created.type === 'duplicate_active_record') {
    response.status(409).json({
      error: 'duplicate_active_record',
      detail: 'This machine already has an active maintenance record',
    });
    return;
  }

  response.status(201).json(serializeMaintenanceRecord(created.record));
}

export async function startMaintenanceRecordHandler(
  request: Request,
  response: Response,
) {
  const parsedId = recordIdSchema.safeParse(request.params.recordId);
  const parsedBody = startMaintenanceRecordSchema.safeParse(request.body ?? {});
  if (!parsedId.success || !parsedBody.success) {
    response.status(400).json({ error: 'invalid_request' });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;
  const updated = await withTransaction(async (client) => {
    const current = await client.query<MaintenanceRecordRow>(
      `
        SELECT
          id,
          machine_id,
          issue_title,
          issue_description,
          priority,
          status,
          reported_by_name,
          started_by_name,
          completed_by_name,
          reported_at,
          started_at,
          completed_at,
          resolution_notes,
          created_at,
          updated_at
        FROM maintenance_records
        WHERE id = $1
        FOR UPDATE
      `,
      [parsedId.data],
    );
    if (current.rowCount === 0) {
      return { type: 'not_found' as const };
    }
    if (current.rows[0].status !== 'MARKED') {
      return { type: 'invalid_status' as const, status: current.rows[0].status };
    }

    const result = await client.query<MaintenanceRecordRow>(
      `
        UPDATE maintenance_records
        SET status = 'IN_PROGRESS',
            started_by_name = COALESCE($2, started_by_name),
            started_at = COALESCE(started_at, NOW()),
            updated_at = NOW()
        WHERE id = $1
        RETURNING
          id,
          machine_id,
          issue_title,
          issue_description,
          priority,
          status,
          reported_by_name,
          started_by_name,
          completed_by_name,
          reported_at,
          started_at,
          completed_at,
          resolution_notes,
          created_at,
          updated_at
      `,
      [parsedId.data, parsedBody.data.startedByName ?? null],
    );

    await writeAuditLog(client, {
      actorType: 'USER',
      actorUserId: authUserId ?? null,
      action: 'maintenance.record_started',
      entityType: 'maintenance_record',
      entityId: String(parsedId.data),
      beforeState: serializeMaintenanceRecord(current.rows[0]),
      afterState: serializeMaintenanceRecord(result.rows[0]),
    });

    return { type: 'updated' as const, record: result.rows[0] };
  });

  if (updated.type === 'not_found') {
    response.status(404).json({ error: 'not_found', detail: 'Maintenance record not found' });
    return;
  }
  if (updated.type === 'invalid_status') {
    response.status(409).json({
      error: 'invalid_status',
      detail: `Only marked maintenance records can be started. Current status: ${updated.status}`,
    });
    return;
  }

  response.json(serializeMaintenanceRecord(updated.record));
}

export async function completeMaintenanceRecordHandler(
  request: Request,
  response: Response,
) {
  const parsedId = recordIdSchema.safeParse(request.params.recordId);
  const parsedBody = completeMaintenanceRecordSchema.safeParse(request.body ?? {});
  if (!parsedId.success || !parsedBody.success) {
    response.status(400).json({ error: 'invalid_request' });
    return;
  }

  const authUserId = response.locals.authUserId as number | undefined;
  const updated = await withTransaction(async (client) => {
    const current = await client.query<MaintenanceRecordRow>(
      `
        SELECT
          id,
          machine_id,
          issue_title,
          issue_description,
          priority,
          status,
          reported_by_name,
          started_by_name,
          completed_by_name,
          reported_at,
          started_at,
          completed_at,
          resolution_notes,
          created_at,
          updated_at
        FROM maintenance_records
        WHERE id = $1
        FOR UPDATE
      `,
      [parsedId.data],
    );
    if (current.rowCount === 0) {
      return { type: 'not_found' as const };
    }
    if (!['MARKED', 'IN_PROGRESS'].includes(current.rows[0].status)) {
      return { type: 'invalid_status' as const, status: current.rows[0].status };
    }

    const machineBeforeResult = await client.query<MachineRow>(
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
      [current.rows[0].machine_id],
    );

    const machineBefore = machineBeforeResult.rows[0];
    const result = await client.query<MaintenanceRecordRow>(
      `
        UPDATE maintenance_records
        SET status = 'COMPLETED',
            started_at = COALESCE(started_at, NOW()),
            completed_by_name = COALESCE($2, completed_by_name),
            completed_at = NOW(),
            resolution_notes = COALESCE($3, resolution_notes),
            updated_at = NOW()
        WHERE id = $1
        RETURNING
          id,
          machine_id,
          issue_title,
          issue_description,
          priority,
          status,
          reported_by_name,
          started_by_name,
          completed_by_name,
          reported_at,
          started_at,
          completed_at,
          resolution_notes,
          created_at,
          updated_at
      `,
      [
        parsedId.data,
        parsedBody.data.completedByName ?? null,
        parsedBody.data.resolutionNotes ?? null,
      ],
    );

    await client.query(
      `
        UPDATE machines
        SET status = 'AVAILABLE',
            current_order_id = NULL,
            cycle_started_at = NULL,
            cycle_ends_at = NULL,
            updated_at = NOW()
        WHERE id = $1
      `,
      [current.rows[0].machine_id],
    );

    const machineAfterResult = await client.query<MachineRow>(
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
      [current.rows[0].machine_id],
    );

    await writeAuditLog(client, {
      actorType: 'USER',
      actorUserId: authUserId ?? null,
      action: 'maintenance.record_completed',
      entityType: 'maintenance_record',
      entityId: String(parsedId.data),
      beforeState: serializeMaintenanceRecord(current.rows[0]),
      afterState: serializeMaintenanceRecord(result.rows[0]),
      metadata: {
        machine: {
          before: serializeMachine(machineBefore),
          after: serializeMachine(machineAfterResult.rows[0]),
        },
      },
    });

    return { type: 'updated' as const, record: result.rows[0] };
  });

  if (updated.type === 'not_found') {
    response.status(404).json({ error: 'not_found', detail: 'Maintenance record not found' });
    return;
  }
  if (updated.type === 'invalid_status') {
    response.status(409).json({
      error: 'invalid_status',
      detail: `This maintenance record cannot be completed from status: ${updated.status}`,
    });
    return;
  }

  response.json(serializeMaintenanceRecord(updated.record));
}

export async function listMaintenanceEligibleMachinesHandler(
  _request: Request,
  response: Response,
) {
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
      WHERE status = 'AVAILABLE'
      ORDER BY type ASC, id ASC
    `,
  );

  response.json(result.rows.map((row) => serializeMachine(row)));
}