BEGIN;

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
  dryer_machine_id BIGINT REFERENCES machines(id),
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

CREATE INDEX IF NOT EXISTS machines_status_idx ON machines(status);
CREATE INDEX IF NOT EXISTS orders_customer_id_idx ON orders(customer_id);
CREATE INDEX IF NOT EXISTS orders_machine_id_idx ON orders(machine_id);
CREATE INDEX IF NOT EXISTS orders_timestamp_idx ON orders(timestamp DESC);
CREATE INDEX IF NOT EXISTS orders_status_idx ON orders(status);
CREATE INDEX IF NOT EXISTS orders_payment_status_idx ON orders(payment_status);
CREATE INDEX IF NOT EXISTS payments_order_id_idx ON payments(order_id);

COMMIT;
