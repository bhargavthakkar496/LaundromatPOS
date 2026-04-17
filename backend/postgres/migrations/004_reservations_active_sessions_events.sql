BEGIN;

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
  wash_option TEXT NOT NULL,
  washer_machine_id BIGINT NOT NULL REFERENCES machines(id),
  dryer_machine_id BIGINT NOT NULL REFERENCES machines(id),
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

CREATE INDEX IF NOT EXISTS machine_reservations_machine_time_idx
  ON machine_reservations(machine_id, start_time, end_time);
CREATE INDEX IF NOT EXISTS machine_events_machine_id_idx
  ON machine_events(machine_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS audit_logs_entity_idx
  ON audit_logs(entity_type, entity_id, created_at DESC);

COMMIT;
