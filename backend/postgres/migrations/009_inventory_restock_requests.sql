BEGIN;

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

CREATE INDEX IF NOT EXISTS inventory_restock_requests_status_idx
  ON inventory_restock_requests(status, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS inventory_purchase_orders_restock_request_idx
  ON inventory_purchase_orders(restock_request_id)
  WHERE restock_request_id IS NOT NULL;

COMMIT;
