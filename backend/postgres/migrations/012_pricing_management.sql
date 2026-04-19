CREATE TABLE IF NOT EXISTS pricing_service_fees (
  service_code TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO pricing_service_fees (service_code, display_name, amount, is_enabled)
VALUES
  ('Washing', 'Washing Service Fee', 15.00, TRUE),
  ('Drying', 'Drying Service Fee', 10.00, TRUE),
  ('Ironing', 'Ironing Service Fee', 20.00, TRUE)
ON CONFLICT (service_code) DO NOTHING;

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