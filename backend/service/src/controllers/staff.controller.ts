import type { Request, Response } from 'express';
import { z } from 'zod';

import { query, withTransaction } from '../db/transaction.js';
import {
  serializeStaffLeaveRequest,
  serializeStaffMember,
  serializeStaffPayout,
  serializeStaffShift,
} from '../services/serializers.js';

type StaffMemberRow = {
  id: number;
  full_name: string;
  role: string;
  phone: string;
  hourly_rate: number | string;
  is_active: boolean;
};

type StaffShiftRow = {
  id: number;
  staff_id: number;
  shift_date: Date | string;
  start_time_label: string;
  end_time_label: string;
  branch: string;
  assignment: string;
  hours: number | string;
};

type StaffLeaveRequestRow = {
  id: number;
  staff_id: number;
  staff_name: string;
  leave_type: string;
  start_date: Date | string;
  end_date: Date | string;
  status: string;
  reason: string;
  requested_at: Date | string;
  reviewed_by_name: string | null;
};

type StaffPayoutRow = {
  id: number;
  staff_id: number;
  staff_name: string;
  period_label: string;
  hours_worked: number | string;
  gross_amount: number | string;
  bonus_amount: number | string;
  deductions_amount: number | string;
  net_amount: number | string;
  status: string;
  created_at: Date | string;
  paid_at: Date | string | null;
};

const staffIdSchema = z.coerce.number().int().positive();
const leaveRequestIdSchema = z.coerce.number().int().positive();
const payoutIdSchema = z.coerce.number().int().positive();
const leaveStatusSchema = z.enum(['PENDING', 'APPROVED', 'REJECTED']);

const shiftListQuerySchema = z.object({
  start: z.string().datetime(),
  end: z.string().datetime(),
});

const shiftWriteSchema = z.object({
  shiftId: z.number().int().positive().optional(),
  staffId: staffIdSchema,
  shiftDate: z.string().datetime(),
  startTimeLabel: z.string().trim().min(1).max(32),
  endTimeLabel: z.string().trim().min(1).max(32),
  branch: z.string().trim().min(1).max(120),
  assignment: z.string().trim().min(1).max(240),
  hours: z.number().positive(),
});

const leaveListQuerySchema = z.object({
  status: leaveStatusSchema.optional(),
});

const leaveUpdateSchema = z.object({
  status: leaveStatusSchema,
  reviewedByName: z.string().trim().max(120).nullable().optional(),
});

const payoutCreateSchema = z.object({
  staffId: staffIdSchema,
  periodLabel: z.string().trim().min(1).max(120),
  hoursWorked: z.number().positive(),
  bonusAmount: z.number().min(0),
  deductionsAmount: z.number().min(0),
});

async function fetchStaffMemberById(staffId: number) {
  const result = await query<StaffMemberRow>(
    `
      SELECT id, full_name, role, phone, hourly_rate, is_active
      FROM staff_members
      WHERE id = $1
    `,
    [staffId],
  );
  return result.rows[0] ?? null;
}

export async function listStaffMembersHandler(
  _request: Request,
  response: Response,
) {
  const result = await query<StaffMemberRow>(
    `
      SELECT id, full_name, role, phone, hourly_rate, is_active
      FROM staff_members
      ORDER BY is_active DESC, role ASC, id ASC
    `,
  );
  response.json(result.rows.map((row) => serializeStaffMember(row)));
}

export async function listStaffShiftsHandler(
  request: Request,
  response: Response,
) {
  const parsed = shiftListQuerySchema.safeParse(request.query);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_staff_shift_query',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const start = new Date(parsed.data.start);
  const end = new Date(parsed.data.end);
  if (!(start < end)) {
    response.status(400).json({
      error: 'invalid_staff_shift_window',
      detail: 'start must be before end',
    });
    return;
  }

  const result = await query<StaffShiftRow>(
    `
      SELECT
        id,
        staff_id,
        shift_date,
        start_time_label,
        end_time_label,
        branch,
        assignment,
        hours
      FROM staff_shifts
      WHERE shift_date >= $1::date
        AND shift_date < $2::date
      ORDER BY shift_date ASC, id ASC
    `,
    [start.toISOString(), end.toISOString()],
  );

  response.json(result.rows.map((row) => serializeStaffShift(row)));
}

export async function saveStaffShiftHandler(
  request: Request,
  response: Response,
) {
  const parsed = shiftWriteSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_staff_shift_request',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const staffMember = await fetchStaffMemberById(parsed.data.staffId);
  if (staffMember == null) {
    response.status(404).json({
      error: 'not_found',
      detail: 'Staff member not found',
    });
    return;
  }

  const shiftDate = new Date(parsed.data.shiftDate);

  const saved = await withTransaction(async (client) => {
    if (parsed.data.shiftId == null) {
      const inserted = await client.query<StaffShiftRow>(
        `
          INSERT INTO staff_shifts (
            staff_id,
            shift_date,
            start_time_label,
            end_time_label,
            branch,
            assignment,
            hours
          )
          VALUES ($1, $2::date, $3, $4, $5, $6, $7)
          RETURNING
            id,
            staff_id,
            shift_date,
            start_time_label,
            end_time_label,
            branch,
            assignment,
            hours
        `,
        [
          parsed.data.staffId,
          shiftDate.toISOString(),
          parsed.data.startTimeLabel,
          parsed.data.endTimeLabel,
          parsed.data.branch,
          parsed.data.assignment,
          parsed.data.hours,
        ],
      );
      return inserted.rows[0];
    }

    const updated = await client.query<StaffShiftRow>(
      `
        UPDATE staff_shifts
        SET
          staff_id = $2,
          shift_date = $3::date,
          start_time_label = $4,
          end_time_label = $5,
          branch = $6,
          assignment = $7,
          hours = $8,
          updated_at = NOW()
        WHERE id = $1
        RETURNING
          id,
          staff_id,
          shift_date,
          start_time_label,
          end_time_label,
          branch,
          assignment,
          hours
      `,
      [
        parsed.data.shiftId,
        parsed.data.staffId,
        shiftDate.toISOString(),
        parsed.data.startTimeLabel,
        parsed.data.endTimeLabel,
        parsed.data.branch,
        parsed.data.assignment,
        parsed.data.hours,
      ],
    );

    if ((updated.rowCount ?? 0) > 0) {
      return updated.rows[0];
    }

    const inserted = await client.query<StaffShiftRow>(
      `
        INSERT INTO staff_shifts (
          id,
          staff_id,
          shift_date,
          start_time_label,
          end_time_label,
          branch,
          assignment,
          hours
        )
        VALUES ($1, $2, $3::date, $4, $5, $6, $7, $8)
        RETURNING
          id,
          staff_id,
          shift_date,
          start_time_label,
          end_time_label,
          branch,
          assignment,
          hours
      `,
      [
        parsed.data.shiftId,
        parsed.data.staffId,
        shiftDate.toISOString(),
        parsed.data.startTimeLabel,
        parsed.data.endTimeLabel,
        parsed.data.branch,
        parsed.data.assignment,
        parsed.data.hours,
      ],
    );
    return inserted.rows[0];
  });

  response.status(parsed.data.shiftId == null ? 201 : 200).json(
    serializeStaffShift(saved),
  );
}

export async function listStaffLeaveRequestsHandler(
  request: Request,
  response: Response,
) {
  const parsed = leaveListQuerySchema.safeParse(request.query);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_staff_leave_query',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const values: unknown[] = [];
  let whereClause = '';
  if (parsed.data.status != null) {
    whereClause = 'WHERE r.status = $1';
    values.push(parsed.data.status);
  }

  const result = await query<StaffLeaveRequestRow>(
    `
      SELECT
        r.id,
        r.staff_id,
        s.full_name AS staff_name,
        r.leave_type,
        r.start_date,
        r.end_date,
        r.status,
        r.reason,
        r.requested_at,
        r.reviewed_by_name
      FROM staff_leave_requests r
      INNER JOIN staff_members s ON s.id = r.staff_id
      ${whereClause}
      ORDER BY r.start_date ASC, r.id ASC
    `,
    values,
  );

  response.json(
    result.rows.map((row) => serializeStaffLeaveRequest(row)),
  );
}

export async function updateStaffLeaveRequestHandler(
  request: Request,
  response: Response,
) {
  const parsedId = leaveRequestIdSchema.safeParse(request.params.leaveRequestId);
  const parsedBody = leaveUpdateSchema.safeParse(request.body);
  if (!parsedId.success || !parsedBody.success) {
    response.status(400).json({
      error: 'invalid_staff_leave_update_request',
    });
    return;
  }

  const updated = await withTransaction(async (client) => {
    const result = await client.query<StaffLeaveRequestRow>(
      `
        UPDATE staff_leave_requests r
        SET
          status = $2,
          reviewed_by_name = $3,
          updated_at = NOW()
        FROM staff_members s
        WHERE r.id = $1
          AND s.id = r.staff_id
        RETURNING
          r.id,
          r.staff_id,
          s.full_name AS staff_name,
          r.leave_type,
          r.start_date,
          r.end_date,
          r.status,
          r.reason,
          r.requested_at,
          r.reviewed_by_name
      `,
      [
        parsedId.data,
        parsedBody.data.status,
        parsedBody.data.reviewedByName ?? null,
      ],
    );
    return result.rows[0] ?? null;
  });

  if (updated == null) {
    response.status(404).json({
      error: 'not_found',
      detail: 'Leave request not found',
    });
    return;
  }

  response.json(serializeStaffLeaveRequest(updated));
}

export async function listStaffPayoutsHandler(
  _request: Request,
  response: Response,
) {
  const result = await query<StaffPayoutRow>(
    `
      SELECT
        p.id,
        p.staff_id,
        s.full_name AS staff_name,
        p.period_label,
        p.hours_worked,
        p.gross_amount,
        p.bonus_amount,
        p.deductions_amount,
        p.net_amount,
        p.status,
        p.created_at,
        p.paid_at
      FROM staff_payouts p
      INNER JOIN staff_members s ON s.id = p.staff_id
      ORDER BY p.created_at DESC, p.id DESC
    `,
  );

  response.json(result.rows.map((row) => serializeStaffPayout(row)));
}

export async function createStaffPayoutHandler(
  request: Request,
  response: Response,
) {
  const parsed = payoutCreateSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({
      error: 'invalid_staff_payout_request',
      detail: parsed.error.flatten(),
    });
    return;
  }

  const staffMember = await fetchStaffMemberById(parsed.data.staffId);
  if (staffMember == null) {
    response.status(404).json({
      error: 'not_found',
      detail: 'Staff member not found',
    });
    return;
  }

  const grossAmount = Number(staffMember.hourly_rate) * parsed.data.hoursWorked;
  const netAmount =
    grossAmount + parsed.data.bonusAmount - parsed.data.deductionsAmount;

  const inserted = await withTransaction(async (client) => {
    const result = await client.query<StaffPayoutRow>(
      `
        INSERT INTO staff_payouts (
          staff_id,
          period_label,
          hours_worked,
          gross_amount,
          bonus_amount,
          deductions_amount,
          net_amount,
          status
        )
        SELECT
          s.id,
          $2,
          $3,
          $4,
          $5,
          $6,
          $7,
          'SCHEDULED'
        FROM staff_members s
        WHERE s.id = $1
        RETURNING
          id,
          staff_id,
          (SELECT full_name FROM staff_members WHERE id = staff_id) AS staff_name,
          period_label,
          hours_worked,
          gross_amount,
          bonus_amount,
          deductions_amount,
          net_amount,
          status,
          created_at,
          paid_at
      `,
      [
        parsed.data.staffId,
        parsed.data.periodLabel,
        parsed.data.hoursWorked,
        grossAmount,
        parsed.data.bonusAmount,
        parsed.data.deductionsAmount,
        netAmount,
      ],
    );
    return result.rows[0];
  });

  response.status(201).json(serializeStaffPayout(inserted));
}

export async function markStaffPayoutPaidHandler(
  request: Request,
  response: Response,
) {
  const parsedId = payoutIdSchema.safeParse(request.params.payoutId);
  if (!parsedId.success) {
    response.status(400).json({
      error: 'invalid_staff_payout_id',
    });
    return;
  }

  const updated = await withTransaction(async (client) => {
    const result = await client.query<StaffPayoutRow>(
      `
        UPDATE staff_payouts p
        SET
          status = 'PAID',
          paid_at = COALESCE(paid_at, NOW()),
          updated_at = NOW()
        FROM staff_members s
        WHERE p.id = $1
          AND s.id = p.staff_id
        RETURNING
          p.id,
          p.staff_id,
          s.full_name AS staff_name,
          p.period_label,
          p.hours_worked,
          p.gross_amount,
          p.bonus_amount,
          p.deductions_amount,
          p.net_amount,
          p.status,
          p.created_at,
          p.paid_at
      `,
      [parsedId.data],
    );
    return result.rows[0] ?? null;
  });

  if (updated == null) {
    response.status(404).json({
      error: 'not_found',
      detail: 'Payout not found',
    });
    return;
  }

  response.json(serializeStaffPayout(updated));
}
