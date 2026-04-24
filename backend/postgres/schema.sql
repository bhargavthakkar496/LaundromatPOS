BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('ADMIN', 'MANAGER', 'CASHIER', 'TECHNICIAN', 'SUPPORT');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'machine_status') THEN
    CREATE TYPE machine_status AS ENUM ('AVAILABLE', 'MAINTENANCE', 'IN_USE', 'READY_FOR_PICKUP');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status') THEN
    CREATE TYPE order_status AS ENUM ('BOOKED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
    CREATE TYPE payment_status AS ENUM ('PENDING', 'PAID', 'FAILED', 'REFUNDED');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_session_status') THEN
    CREATE TYPE payment_session_status AS ENUM ('AWAITING_SCAN', 'PROCESSING', 'PAID', 'FAILED');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'reservation_status') THEN
    CREATE TYPE reservation_status AS ENUM ('BOOKED', 'FULFILLED', 'CANCELLED');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'active_order_session_stage') THEN
    CREATE TYPE active_order_session_stage AS ENUM ('DRAFT', 'BOOKED', 'PAID');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'machine_event_type') THEN
    CREATE TYPE machine_event_type AS ENUM ('STATUS_CHANGED', 'TELEMETRY', 'LIFECYCLE');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'audit_actor_type') THEN
    CREATE TYPE audit_actor_type AS ENUM ('USER', 'SYSTEM', 'DEVICE', 'CUSTOMER');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_leave_status') THEN
    CREATE TYPE staff_leave_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_payout_status') THEN
    CREATE TYPE staff_payout_status AS ENUM ('SCHEDULED', 'PAID');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  username CITEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  pin_hash TEXT NOT NULL,
  role user_role NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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

CREATE TABLE IF NOT EXISTS auth_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id BIGINT NOT NULL REFERENCES users(id),
  access_token_hash TEXT NOT NULL,
  refresh_token_hash TEXT,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  device_label TEXT,
  ip_address INET,
  user_agent TEXT
);

CREATE TABLE IF NOT EXISTS devices (
  id BIGSERIAL PRIMARY KEY,
  device_code TEXT NOT NULL UNIQUE,
  device_name TEXT NOT NULL,
  device_type TEXT NOT NULL,
  platform TEXT,
  status TEXT NOT NULL DEFAULT 'ACTIVE',
  last_seen_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS customers (
  id BIGSERIAL PRIMARY KEY,
  full_name TEXT NOT NULL,
  phone CITEXT NOT NULL UNIQUE,
  preferred_washer_size_kg INTEGER,
  preferred_detergent_add_on TEXT,
  preferred_dryer_duration_minutes INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS machines (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL,
  capacity_kg INTEGER NOT NULL,
  price NUMERIC(12,2) NOT NULL,
  status machine_status NOT NULL DEFAULT 'AVAILABLE',
  current_order_id BIGINT,
  cycle_started_at TIMESTAMPTZ,
  cycle_ends_at TIMESTAMPTZ,
  telemetry_source TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orders (
  id BIGSERIAL PRIMARY KEY,
  machine_id BIGINT NOT NULL REFERENCES machines(id),
  customer_id BIGINT NOT NULL REFERENCES customers(id),
  created_by_user_id BIGINT REFERENCES users(id),
  service_type TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  status order_status NOT NULL,
  payment_method TEXT NOT NULL,
  payment_status payment_status NOT NULL,
  payment_reference TEXT NOT NULL UNIQUE,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  load_size_kg INTEGER,
  wash_option TEXT,
  selected_services TEXT[] NOT NULL DEFAULT ARRAY['Washing', 'Drying']::TEXT[],
  dryer_machine_id BIGINT REFERENCES machines(id),
  ironing_machine_id BIGINT REFERENCES machines(id),
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE machines DROP CONSTRAINT IF EXISTS machines_current_order_fk;
ALTER TABLE machines
  ADD CONSTRAINT machines_current_order_fk
  FOREIGN KEY (current_order_id) REFERENCES orders(id);

CREATE TABLE IF NOT EXISTS payments (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT REFERENCES orders(id),
  amount NUMERIC(12,2) NOT NULL,
  payment_method TEXT NOT NULL,
  payment_status payment_status NOT NULL,
  reference TEXT NOT NULL UNIQUE,
  gateway_name TEXT,
  gateway_transaction_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  settled_at TIMESTAMPTZ,
  failure_reason TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB
);

CREATE TABLE IF NOT EXISTS refund_requests (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING',
  requested_by_name TEXT,
  processed_by_name TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS refund_requests_one_pending_per_order_idx
  ON refund_requests(order_id)
  WHERE status = 'PENDING';

CREATE TABLE IF NOT EXISTS pricing_service_fees (
  service_code TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pricing_campaigns (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  discount_type TEXT NOT NULL,
  discount_value NUMERIC(12,2) NOT NULL,
  applies_to_service TEXT,
  min_order_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS pricing_campaigns_active_idx
  ON pricing_campaigns(is_active, created_at DESC);

CREATE TABLE IF NOT EXISTS maintenance_records (
  id BIGSERIAL PRIMARY KEY,
  machine_id BIGINT NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
  issue_title TEXT NOT NULL,
  issue_description TEXT,
  priority TEXT NOT NULL DEFAULT 'MEDIUM',
  status TEXT NOT NULL DEFAULT 'MARKED',
  reported_by_name TEXT,
  started_by_name TEXT,
  completed_by_name TEXT,
  reported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  resolution_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS maintenance_records_machine_idx
  ON maintenance_records(machine_id, created_at DESC);
CREATE INDEX IF NOT EXISTS maintenance_records_status_idx
  ON maintenance_records(status, created_at DESC);
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

CREATE TABLE IF NOT EXISTS payment_sessions (
  id BIGSERIAL PRIMARY KEY,
  amount NUMERIC(12,2) NOT NULL,
  payment_method TEXT NOT NULL,
  reference TEXT NOT NULL UNIQUE,
  qr_payload TEXT NOT NULL,
  status payment_session_status NOT NULL,
  attempt INTEGER NOT NULL DEFAULT 1,
  should_fail BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  failure_reason TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB
);

CREATE TABLE IF NOT EXISTS machine_reservations (
  id BIGSERIAL PRIMARY KEY,
  machine_id BIGINT NOT NULL REFERENCES machines(id),
  customer_id BIGINT NOT NULL REFERENCES customers(id),
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  status reservation_status NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  preferred_washer_size_kg INTEGER,
  detergent_add_on TEXT,
  dryer_duration_minutes INTEGER
);

CREATE TABLE IF NOT EXISTS active_order_sessions (
  id BIGSERIAL PRIMARY KEY,
  customer_name TEXT NOT NULL,
  customer_phone CITEXT NOT NULL,
  load_size_kg INTEGER NOT NULL,
  selected_services TEXT[] NOT NULL DEFAULT ARRAY['Washing', 'Drying']::TEXT[],
  wash_option TEXT,
  washer_machine_id BIGINT REFERENCES machines(id),
  dryer_machine_id BIGINT REFERENCES machines(id),
  ironing_machine_id BIGINT REFERENCES machines(id),
  payment_method TEXT NOT NULL,
  stage active_order_session_stage NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  confirmed_by TEXT,
  order_id BIGINT REFERENCES orders(id),
  payment_reference TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inventory_suppliers (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  contact_name TEXT,
  phone TEXT,
  email TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inventory_items (
  id BIGSERIAL PRIMARY KEY,
  sku TEXT NOT NULL UNIQUE,
  barcode TEXT UNIQUE,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  unit TEXT NOT NULL,
  unit_type TEXT NOT NULL DEFAULT 'PACKAGE',
  pack_size TEXT,
  quantity_on_hand INTEGER NOT NULL DEFAULT 0,
  reorder_point INTEGER NOT NULL DEFAULT 0,
  par_level INTEGER NOT NULL DEFAULT 0,
  unit_cost NUMERIC(12,2) NOT NULL DEFAULT 0,
  selling_price NUMERIC(12,2),
  supplier_id BIGINT REFERENCES inventory_suppliers(id),
  branch_name TEXT NOT NULL,
  location_name TEXT NOT NULL,
  last_restocked_at TIMESTAMPTZ,
  expires_at DATE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inventory_stock_movements (
  id BIGSERIAL PRIMARY KEY,
  inventory_item_id BIGINT NOT NULL REFERENCES inventory_items(id),
  movement_type TEXT NOT NULL,
  quantity_delta INTEGER NOT NULL,
  balance_after INTEGER NOT NULL,
  reference_type TEXT,
  reference_id TEXT,
  notes TEXT,
  performed_by_user_id BIGINT REFERENCES users(id),
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inventory_purchase_orders (
  id BIGSERIAL PRIMARY KEY,
  po_number TEXT NOT NULL UNIQUE,
  supplier_id BIGINT REFERENCES inventory_suppliers(id),
  status TEXT NOT NULL,
  branch_name TEXT NOT NULL,
  expected_delivery_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inventory_restock_requests (
  id BIGSERIAL PRIMARY KEY,
  request_number TEXT NOT NULL UNIQUE,
  inventory_item_id BIGINT NOT NULL REFERENCES inventory_items(id),
  requested_quantity INTEGER NOT NULL,
  status TEXT NOT NULL,
  request_notes TEXT,
  operator_remarks TEXT,
  requested_by_user_id BIGINT REFERENCES users(id),
  approved_by_user_id BIGINT REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  approved_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE inventory_purchase_orders
  ADD COLUMN IF NOT EXISTS restock_request_id BIGINT REFERENCES inventory_restock_requests(id);

CREATE UNIQUE INDEX IF NOT EXISTS active_order_sessions_single_active_idx
ON active_order_sessions ((is_active))
WHERE is_active = TRUE;

CREATE TABLE IF NOT EXISTS machine_events (
  id BIGSERIAL PRIMARY KEY,
  machine_id BIGINT NOT NULL REFERENCES machines(id),
  order_id BIGINT REFERENCES orders(id),
  device_id BIGINT REFERENCES devices(id),
  event_type machine_event_type NOT NULL,
  status machine_status,
  cycle_started_at TIMESTAMPTZ,
  cycle_ends_at TIMESTAMPTZ,
  source TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id BIGSERIAL PRIMARY KEY,
  actor_type audit_actor_type NOT NULL,
  actor_user_id BIGINT REFERENCES users(id),
  actor_device_id BIGINT REFERENCES devices(id),
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  request_id UUID,
  before_state JSONB,
  after_state JSONB,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS customers_phone_idx ON customers(phone);
CREATE INDEX IF NOT EXISTS machines_status_idx ON machines(status);
CREATE INDEX IF NOT EXISTS orders_customer_id_idx ON orders(customer_id);
CREATE INDEX IF NOT EXISTS orders_machine_id_idx ON orders(machine_id);
CREATE INDEX IF NOT EXISTS orders_timestamp_idx ON orders(timestamp DESC);
CREATE INDEX IF NOT EXISTS orders_status_idx ON orders(status);
CREATE INDEX IF NOT EXISTS orders_payment_status_idx ON orders(payment_status);
CREATE INDEX IF NOT EXISTS payments_order_id_idx ON payments(order_id);
CREATE INDEX IF NOT EXISTS inventory_items_category_idx
  ON inventory_items(category);
CREATE INDEX IF NOT EXISTS inventory_items_supplier_id_idx
  ON inventory_items(supplier_id);
CREATE INDEX IF NOT EXISTS inventory_items_branch_location_idx
  ON inventory_items(branch_name, location_name);
CREATE INDEX IF NOT EXISTS inventory_items_quantity_idx
  ON inventory_items(quantity_on_hand);
CREATE INDEX IF NOT EXISTS inventory_stock_movements_item_time_idx
  ON inventory_stock_movements(inventory_item_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS inventory_purchase_orders_status_idx
  ON inventory_purchase_orders(status);
CREATE INDEX IF NOT EXISTS inventory_restock_requests_status_idx
  ON inventory_restock_requests(status, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS inventory_purchase_orders_restock_request_idx
  ON inventory_purchase_orders(restock_request_id)
  WHERE restock_request_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS machine_reservations_machine_time_idx
  ON machine_reservations(machine_id, start_time, end_time);
CREATE INDEX IF NOT EXISTS machine_events_machine_id_idx
  ON machine_events(machine_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS audit_logs_entity_idx
  ON audit_logs(entity_type, entity_id, created_at DESC);

INSERT INTO users (username, display_name, pin_hash, role)
VALUES ('admin', 'Store Admin', 'sha256:03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', 'ADMIN')
ON CONFLICT (username) DO NOTHING;

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

INSERT INTO machines (id, name, type, capacity_kg, price, status)
VALUES
  (1, 'Washer 01', 'Washer', 8, 120.00, 'AVAILABLE'),
  (2, 'Dryer 02', 'Dryer', 10, 150.00, 'AVAILABLE'),
  (3, 'Washer 03', 'Washer', 12, 180.00, 'AVAILABLE'),
  (4, 'Washer 04', 'Washer', 9, 130.00, 'AVAILABLE'),
  (5, 'Washer 05', 'Washer', 11, 165.00, 'AVAILABLE'),
  (6, 'Washer 06', 'Washer', 14, 210.00, 'AVAILABLE'),
  (7, 'Dryer 04', 'Dryer', 9, 135.00, 'AVAILABLE'),
  (8, 'Dryer 05', 'Dryer', 12, 170.00, 'AVAILABLE'),
  (9, 'Dryer 06', 'Dryer', 15, 220.00, 'AVAILABLE')
ON CONFLICT (id) DO NOTHING;

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

INSERT INTO inventory_suppliers (id, name, contact_name, phone, email)
VALUES
  (1, 'Sparkle Supply Co', 'Riya Menon', '9876500011', 'sparkle@example.com'),
  (2, 'FreshFold Traders', 'Kunal Shah', '9876500012', 'freshfold@example.com'),
  (3, 'CleanChem Distributors', 'Maya Iyer', '9876500013', 'cleanchem@example.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO inventory_items (
  id,
  sku,
  barcode,
  name,
  category,
  unit,
  unit_type,
  pack_size,
  quantity_on_hand,
  reorder_point,
  par_level,
  unit_cost,
  selling_price,
  supplier_id,
  branch_name,
  location_name,
  last_restocked_at,
  expires_at
)
VALUES
  (1, 'DET-ULTRA-5KG', '8901001000011', 'Ultra Wash Powder', 'Detergent', 'bags', 'PACKAGE', '5 kg bag', 5, 8, 12, 410.00, 560.00, 1, 'Main Branch', 'Aisle A1', NOW() - INTERVAL '2 days', NULL),
  (2, 'DET-ECO-4KG', '8901001000012', 'Eco Fresh Powder', 'Detergent', 'bags', 'PACKAGE', '4 kg bag', 14, 6, 10, 360.00, 495.00, 1, 'Main Branch', 'Aisle A1', NOW() - INTERVAL '8 days', NULL),
  (3, 'SOAP-BAR-24', '8901001000013', 'Bar Soap Classic', 'Soap', 'bars', 'UNIT', '24-bar carton', 22, 10, 18, 28.00, 38.00, 2, 'Main Branch', 'Aisle B1', NOW() - INTERVAL '5 days', DATE '2026-06-14'),
  (4, 'SOAP-HAND-12', '8901001000014', 'Hand Soap Backup', 'Soap', 'bars', 'UNIT', '12-bar sleeve', 4, 6, 10, 34.00, 48.00, 2, 'Main Branch', 'Aisle B2', NOW() - INTERVAL '11 days', DATE '2026-05-02'),
  (5, 'LIQ-PRO-20L', '8901001000015', 'Liquid Wash Pro', 'Liquid', 'canisters', 'LIQUID_CONTAINER', '20 L canister', 9, 5, 8, 620.00, NULL, 1, 'Main Branch', 'Aisle C1', NOW() - INTERVAL '3 days', NULL),
  (6, 'LIQ-EXP-20L', '8901001000016', 'Express Liquid', 'Liquid', 'canisters', 'LIQUID_CONTAINER', '20 L canister', 3, 5, 8, 590.00, NULL, 1, 'North Branch', 'Aisle C1', NOW() - INTERVAL '16 days', NULL),
  (7, 'DIS-WIPE-5L', '8901001000017', 'Wipe Down Spray', 'Disinfectant', 'bottles', 'LIQUID_CONTAINER', '5 L bottle', 2, 4, 6, 180.00, NULL, 3, 'Main Branch', 'Aisle D1', NOW() - INTERVAL '12 days', DATE '2026-04-25'),
  (8, 'DIS-DRUM-5L', '8901001000018', 'Drum Sanitizer', 'Disinfectant', 'bottles', 'LIQUID_CONTAINER', '5 L bottle', 6, 4, 6, 205.00, NULL, 3, 'North Branch', 'Aisle D2', NOW() - INTERVAL '6 days', DATE '2026-06-02'),
  (9, 'BLE-WHITE-10L', '8901001000019', 'White Bright Bleach', 'Bleach', 'jugs', 'LIQUID_CONTAINER', '10 L jug', 10, 5, 8, 245.00, NULL, 3, 'Main Branch', 'Aisle E1', NOW() - INTERVAL '4 days', NULL),
  (10, 'BLE-HEAVY-10L', '8901001000020', 'Heavy Duty Bleach', 'Bleach', 'jugs', 'LIQUID_CONTAINER', '10 L jug', 5, 6, 8, 265.00, NULL, 3, 'North Branch', 'Aisle E2', NOW() - INTERVAL '13 days', NULL),
  (11, 'SOFT-LAV-5L', '8901001000021', 'Lavender Softener', 'Softener', 'pouches', 'PACKAGE', '5 L pouch', 13, 6, 10, 155.00, 220.00, 2, 'Main Branch', 'Aisle F1', NOW() - INTERVAL '7 days', DATE '2026-05-15'),
  (12, 'SOFT-BABY-5L', '8901001000022', 'Baby Soft Mix', 'Softener', 'pouches', 'PACKAGE', '5 L pouch', 0, 4, 8, 165.00, 230.00, 2, 'North Branch', 'Aisle F2', NOW() - INTERVAL '19 days', DATE '2026-04-29')
ON CONFLICT (id) DO NOTHING;

INSERT INTO inventory_purchase_orders (
  id,
  po_number,
  supplier_id,
  status,
  branch_name,
  expected_delivery_at,
  notes
)
VALUES
  (1, 'PO-INV-1001', 1, 'PENDING', 'Main Branch', NOW() + INTERVAL '2 days', 'Detergent refill for premium wash line'),
  (2, 'PO-INV-1002', 3, 'ORDERED', 'North Branch', NOW() + INTERVAL '3 days', 'Disinfectant and bleach restock'),
  (3, 'PO-INV-1003', 2, 'RECEIVED', 'Main Branch', NOW() - INTERVAL '1 day', 'Softener replenishment')
ON CONFLICT (id) DO NOTHING;

INSERT INTO inventory_stock_movements (
  inventory_item_id,
  movement_type,
  quantity_delta,
  balance_after,
  reference_type,
  reference_id,
  notes,
  occurred_at
)
VALUES
  (1, 'RECEIVED', 12, 12, 'PO', 'PO-INV-1001', 'Supplier delivery for premium detergent shelf.', NOW() - INTERVAL '8 days'),
  (1, 'CONSUMED', -4, 8, 'SHIFT_USAGE', 'SHIFT-401', 'Washer bay daily detergent consumption.', NOW() - INTERVAL '5 days'),
  (1, 'DAMAGED', -1, 7, 'INCIDENT', 'INC-DET-01', 'One bag torn during unloading.', NOW() - INTERVAL '4 days'),
  (1, 'CONSUMED', -2, 5, 'SHIFT_USAGE', 'SHIFT-404', 'Consumed during express wash cycle run.', NOW() - INTERVAL '2 days'),
  (2, 'RECEIVED', 20, 20, 'PO', 'PO-INV-1004', 'Bulk detergent top-up from Sparkle Supply Co.', NOW() - INTERVAL '14 days'),
  (2, 'TRANSFERRED', -4, 16, 'TRANSFER', 'TRN-DET-22', 'Moved cartons to branch floor stock.', NOW() - INTERVAL '10 days'),
  (2, 'CONSUMED', -2, 14, 'SHIFT_USAGE', 'SHIFT-395', 'Routine stock issue to wash line.', NOW() - INTERVAL '8 days'),
  (7, 'RECEIVED', 6, 6, 'PO', 'PO-INV-1002', 'Disinfectant delivery received.', NOW() - INTERVAL '15 days'),
  (7, 'CONSUMED', -3, 3, 'SHIFT_USAGE', 'SHIFT-399', 'Sanitizing drum-clean cycle stock issue.', NOW() - INTERVAL '11 days'),
  (7, 'DAMAGED', -1, 2, 'INCIDENT', 'INC-DIS-03', 'Bottle leak found during shelf check.', NOW() - INTERVAL '9 days'),
  (12, 'MANUAL_CORRECTION', -2, 2, 'AUDIT', 'AUD-2201', 'Physical count corrected after audit variance.', NOW() - INTERVAL '21 days'),
  (12, 'CONSUMED', -2, 0, 'SHIFT_USAGE', 'SHIFT-388', 'Softener pouch stock fully consumed.', NOW() - INTERVAL '19 days');

COMMIT;
