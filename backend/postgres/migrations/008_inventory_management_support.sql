BEGIN;

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
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  unit TEXT NOT NULL,
  quantity_on_hand INTEGER NOT NULL DEFAULT 0,
  reorder_point INTEGER NOT NULL DEFAULT 0,
  unit_cost NUMERIC(12,2) NOT NULL DEFAULT 0,
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

CREATE INDEX IF NOT EXISTS inventory_items_category_idx
  ON inventory_items(category);
CREATE INDEX IF NOT EXISTS inventory_items_supplier_id_idx
  ON inventory_items(supplier_id);
CREATE INDEX IF NOT EXISTS inventory_items_branch_location_idx
  ON inventory_items(branch_name, location_name);
CREATE INDEX IF NOT EXISTS inventory_items_quantity_idx
  ON inventory_items(quantity_on_hand);
CREATE INDEX IF NOT EXISTS inventory_purchase_orders_status_idx
  ON inventory_purchase_orders(status);

INSERT INTO inventory_suppliers (id, name, contact_name, phone, email)
VALUES
  (1, 'Sparkle Supply Co', 'Riya Menon', '9876500011', 'sparkle@example.com'),
  (2, 'FreshFold Traders', 'Kunal Shah', '9876500012', 'freshfold@example.com'),
  (3, 'CleanChem Distributors', 'Maya Iyer', '9876500013', 'cleanchem@example.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO inventory_items (
  id,
  sku,
  name,
  category,
  unit,
  quantity_on_hand,
  reorder_point,
  unit_cost,
  supplier_id,
  branch_name,
  location_name,
  last_restocked_at,
  expires_at
)
VALUES
  (1, 'DET-ULTRA-5KG', 'Ultra Wash Powder', 'Detergent', 'bags', 5, 8, 410.00, 1, 'Main Branch', 'Aisle A1', NOW() - INTERVAL '2 days', NULL),
  (2, 'DET-ECO-4KG', 'Eco Fresh Powder', 'Detergent', 'bags', 14, 6, 360.00, 1, 'Main Branch', 'Aisle A1', NOW() - INTERVAL '8 days', NULL),
  (3, 'SOAP-BAR-24', 'Bar Soap Classic', 'Soap', 'bars', 22, 10, 28.00, 2, 'Main Branch', 'Aisle B1', NOW() - INTERVAL '5 days', DATE '2026-06-14'),
  (4, 'SOAP-HAND-12', 'Hand Soap Backup', 'Soap', 'bars', 4, 6, 34.00, 2, 'Main Branch', 'Aisle B2', NOW() - INTERVAL '11 days', DATE '2026-05-02'),
  (5, 'LIQ-PRO-20L', 'Liquid Wash Pro', 'Liquid', 'canisters', 9, 5, 620.00, 1, 'Main Branch', 'Aisle C1', NOW() - INTERVAL '3 days', NULL),
  (6, 'LIQ-EXP-20L', 'Express Liquid', 'Liquid', 'canisters', 3, 5, 590.00, 1, 'North Branch', 'Aisle C1', NOW() - INTERVAL '16 days', NULL),
  (7, 'DIS-WIPE-5L', 'Wipe Down Spray', 'Disinfectant', 'bottles', 2, 4, 180.00, 3, 'Main Branch', 'Aisle D1', NOW() - INTERVAL '12 days', DATE '2026-04-25'),
  (8, 'DIS-DRUM-5L', 'Drum Sanitizer', 'Disinfectant', 'bottles', 6, 4, 205.00, 3, 'North Branch', 'Aisle D2', NOW() - INTERVAL '6 days', DATE '2026-06-02'),
  (9, 'BLE-WHITE-10L', 'White Bright Bleach', 'Bleach', 'jugs', 10, 5, 245.00, 3, 'Main Branch', 'Aisle E1', NOW() - INTERVAL '4 days', NULL),
  (10, 'BLE-HEAVY-10L', 'Heavy Duty Bleach', 'Bleach', 'jugs', 5, 6, 265.00, 3, 'North Branch', 'Aisle E2', NOW() - INTERVAL '13 days', NULL),
  (11, 'SOFT-LAV-5L', 'Lavender Softener', 'Softener', 'pouches', 13, 6, 155.00, 2, 'Main Branch', 'Aisle F1', NOW() - INTERVAL '7 days', DATE '2026-05-15'),
  (12, 'SOFT-BABY-5L', 'Baby Soft Mix', 'Softener', 'pouches', 0, 4, 165.00, 2, 'North Branch', 'Aisle F2', NOW() - INTERVAL '19 days', DATE '2026-04-29')
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

COMMIT;
