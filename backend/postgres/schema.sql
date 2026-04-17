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
CREATE INDEX IF NOT EXISTS machine_reservations_machine_time_idx
  ON machine_reservations(machine_id, start_time, end_time);
CREATE INDEX IF NOT EXISTS machine_events_machine_id_idx
  ON machine_events(machine_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS audit_logs_entity_idx
  ON audit_logs(entity_type, entity_id, created_at DESC);

INSERT INTO users (username, display_name, pin_hash, role)
VALUES ('admin', 'Store Admin', 'sha256:03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', 'ADMIN')
ON CONFLICT (username) DO NOTHING;

INSERT INTO machines (id, name, type, capacity_kg, price, status)
VALUES
  (1, 'Washer 01', 'Washer', 8, 120.00, 'AVAILABLE'),
  (2, 'Dryer 02', 'Dryer', 10, 150.00, 'AVAILABLE'),
  (3, 'Washer 03', 'Washer', 12, 180.00, 'MAINTENANCE'),
  (4, 'Washer 04', 'Washer', 9, 130.00, 'AVAILABLE'),
  (5, 'Washer 05', 'Washer', 11, 165.00, 'AVAILABLE'),
  (6, 'Washer 06', 'Washer', 14, 210.00, 'AVAILABLE'),
  (7, 'Dryer 04', 'Dryer', 9, 135.00, 'AVAILABLE'),
  (8, 'Dryer 05', 'Dryer', 12, 170.00, 'AVAILABLE'),
  (9, 'Dryer 06', 'Dryer', 15, 220.00, 'AVAILABLE')
ON CONFLICT (id) DO NOTHING;

COMMIT;
