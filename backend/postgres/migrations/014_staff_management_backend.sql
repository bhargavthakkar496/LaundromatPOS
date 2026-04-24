BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_leave_status') THEN
    CREATE TYPE staff_leave_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_payout_status') THEN
    CREATE TYPE staff_payout_status AS ENUM ('SCHEDULED', 'PAID');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS staff_members (
  id BIGSERIAL PRIMARY KEY,
  full_name TEXT NOT NULL,
  role user_role NOT NULL,
  phone TEXT NOT NULL UNIQUE,
  hourly_rate NUMERIC(12,2) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS staff_shifts (
  id BIGSERIAL PRIMARY KEY,
  staff_id BIGINT NOT NULL REFERENCES staff_members(id) ON DELETE CASCADE,
  shift_date DATE NOT NULL,
  start_time_label TEXT NOT NULL,
  end_time_label TEXT NOT NULL,
  branch TEXT NOT NULL,
  assignment TEXT NOT NULL,
  hours NUMERIC(8,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS staff_leave_requests (
  id BIGSERIAL PRIMARY KEY,
  staff_id BIGINT NOT NULL REFERENCES staff_members(id) ON DELETE CASCADE,
  leave_type TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status staff_leave_status NOT NULL DEFAULT 'PENDING',
  reason TEXT NOT NULL,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_by_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS staff_payouts (
  id BIGSERIAL PRIMARY KEY,
  staff_id BIGINT NOT NULL REFERENCES staff_members(id) ON DELETE CASCADE,
  period_label TEXT NOT NULL,
  hours_worked NUMERIC(10,2) NOT NULL,
  gross_amount NUMERIC(12,2) NOT NULL,
  bonus_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  deductions_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  net_amount NUMERIC(12,2) NOT NULL,
  status staff_payout_status NOT NULL DEFAULT 'SCHEDULED',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  paid_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS staff_members_role_idx
  ON staff_members(role, is_active);
CREATE INDEX IF NOT EXISTS staff_shifts_staff_date_idx
  ON staff_shifts(staff_id, shift_date);
CREATE INDEX IF NOT EXISTS staff_shifts_date_idx
  ON staff_shifts(shift_date);
CREATE INDEX IF NOT EXISTS staff_leave_requests_status_idx
  ON staff_leave_requests(status, start_date);
CREATE INDEX IF NOT EXISTS staff_payouts_status_idx
  ON staff_payouts(status, created_at DESC);

INSERT INTO staff_members (id, full_name, role, phone, hourly_rate, is_active)
VALUES
  (1, 'Store Admin', 'ADMIN', '9999999999', 220.00, TRUE),
  (2, 'Kiran Patel', 'CASHIER', '9876500011', 120.00, TRUE),
  (3, 'Meera Shah', 'MANAGER', '9876500012', 180.00, TRUE),
  (4, 'Ravi Solanki', 'TECHNICIAN', '9876500013', 150.00, TRUE),
  (5, 'Neha Joshi', 'SUPPORT', '9876500014', 110.00, TRUE)
ON CONFLICT (id) DO UPDATE
SET
  full_name = EXCLUDED.full_name,
  role = EXCLUDED.role,
  phone = EXCLUDED.phone,
  hourly_rate = EXCLUDED.hourly_rate,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

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
VALUES
  (1, 2, CURRENT_DATE, '08:00', '16:00', 'Main Branch', 'Front counter and handover', 8.00),
  (2, 3, CURRENT_DATE, '10:00', '18:00', 'Main Branch', 'Floor supervision and approvals', 8.00),
  (3, 4, CURRENT_DATE + INTERVAL '1 day', '09:00', '17:00', 'North Branch', 'Machine servicing round', 8.00),
  (4, 5, CURRENT_DATE + INTERVAL '2 days', '12:00', '20:00', 'Main Branch', 'Customer support and pickup queue', 8.00)
ON CONFLICT (id) DO NOTHING;

INSERT INTO staff_leave_requests (
  id,
  staff_id,
  leave_type,
  start_date,
  end_date,
  status,
  reason,
  requested_at,
  reviewed_by_name
)
VALUES
  (1, 2, 'Casual Leave', CURRENT_DATE + INTERVAL '3 days', CURRENT_DATE + INTERVAL '4 days', 'PENDING', 'Family function out of town.', NOW() - INTERVAL '1 day', NULL),
  (2, 4, 'Sick Leave', CURRENT_DATE - INTERVAL '2 days', CURRENT_DATE - INTERVAL '1 day', 'APPROVED', 'Recovery after viral fever.', NOW() - INTERVAL '4 days', 'Store Admin')
ON CONFLICT (id) DO NOTHING;

INSERT INTO staff_payouts (
  id,
  staff_id,
  period_label,
  hours_worked,
  gross_amount,
  bonus_amount,
  deductions_amount,
  net_amount,
  status,
  created_at,
  paid_at
)
VALUES
  (1, 2, '01 Apr - 15 Apr', 96.00, 11520.00, 600.00, 200.00, 11920.00, 'SCHEDULED', TIMESTAMPTZ '2026-04-15 18:00:00+00', NULL),
  (2, 4, '01 Apr - 15 Apr', 88.00, 13200.00, 450.00, 0.00, 13650.00, 'PAID', TIMESTAMPTZ '2026-04-15 18:00:00+00', TIMESTAMPTZ '2026-04-16 11:00:00+00')
ON CONFLICT (id) DO NOTHING;

UPDATE machines
SET status = 'AVAILABLE',
    updated_at = NOW()
WHERE id = 3
  AND status = 'MAINTENANCE'
  AND NOT EXISTS (
    SELECT 1
    FROM maintenance_records
    WHERE machine_id = 3
      AND status <> 'COMPLETED'
  );

COMMIT;
