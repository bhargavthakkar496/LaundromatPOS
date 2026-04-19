BEGIN;

ALTER TABLE inventory_items
  ADD COLUMN IF NOT EXISTS barcode TEXT,
  ADD COLUMN IF NOT EXISTS unit_type TEXT NOT NULL DEFAULT 'PACKAGE',
  ADD COLUMN IF NOT EXISTS pack_size TEXT,
  ADD COLUMN IF NOT EXISTS par_level INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS selling_price NUMERIC(12,2);

CREATE UNIQUE INDEX IF NOT EXISTS inventory_items_barcode_idx
  ON inventory_items(barcode)
  WHERE barcode IS NOT NULL;

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

CREATE INDEX IF NOT EXISTS inventory_stock_movements_item_time_idx
  ON inventory_stock_movements(inventory_item_id, occurred_at DESC);

UPDATE inventory_items
SET barcode = CASE id
      WHEN 1 THEN '8901001000011'
      WHEN 2 THEN '8901001000012'
      WHEN 3 THEN '8901001000013'
      WHEN 4 THEN '8901001000014'
      WHEN 5 THEN '8901001000015'
      WHEN 6 THEN '8901001000016'
      WHEN 7 THEN '8901001000017'
      WHEN 8 THEN '8901001000018'
      WHEN 9 THEN '8901001000019'
      WHEN 10 THEN '8901001000020'
      WHEN 11 THEN '8901001000021'
      WHEN 12 THEN '8901001000022'
      ELSE barcode
    END,
    unit_type = CASE
      WHEN category IN ('Liquid', 'Disinfectant', 'Bleach') THEN 'LIQUID_CONTAINER'
      WHEN category = 'Soap' THEN 'UNIT'
      ELSE 'PACKAGE'
    END,
    pack_size = CASE id
      WHEN 1 THEN '5 kg bag'
      WHEN 2 THEN '4 kg bag'
      WHEN 3 THEN '24-bar carton'
      WHEN 4 THEN '12-bar sleeve'
      WHEN 5 THEN '20 L canister'
      WHEN 6 THEN '20 L canister'
      WHEN 7 THEN '5 L bottle'
      WHEN 8 THEN '5 L bottle'
      WHEN 9 THEN '10 L jug'
      WHEN 10 THEN '10 L jug'
      WHEN 11 THEN '5 L pouch'
      WHEN 12 THEN '5 L pouch'
      ELSE pack_size
    END,
    par_level = CASE id
      WHEN 1 THEN 12
      WHEN 2 THEN 10
      WHEN 3 THEN 18
      WHEN 4 THEN 10
      WHEN 5 THEN 8
      WHEN 6 THEN 8
      WHEN 7 THEN 6
      WHEN 8 THEN 6
      WHEN 9 THEN 8
      WHEN 10 THEN 8
      WHEN 11 THEN 10
      WHEN 12 THEN 8
      ELSE par_level
    END,
    selling_price = CASE id
      WHEN 1 THEN 560.00
      WHEN 2 THEN 495.00
      WHEN 3 THEN 38.00
      WHEN 4 THEN 48.00
      WHEN 11 THEN 220.00
      WHEN 12 THEN 230.00
      ELSE selling_price
    END
WHERE id BETWEEN 1 AND 12;

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
SELECT *
FROM (
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
    (12, 'CONSUMED', -2, 0, 'SHIFT_USAGE', 'SHIFT-388', 'Softener pouch stock fully consumed.', NOW() - INTERVAL '19 days')
) AS seed(
  inventory_item_id,
  movement_type,
  quantity_delta,
  balance_after,
  reference_type,
  reference_id,
  notes,
  occurred_at
)
WHERE NOT EXISTS (
  SELECT 1
  FROM inventory_stock_movements existing
  WHERE existing.inventory_item_id = seed.inventory_item_id
    AND existing.reference_type IS NOT DISTINCT FROM seed.reference_type
    AND existing.reference_id IS NOT DISTINCT FROM seed.reference_id
    AND existing.movement_type = seed.movement_type
);

COMMIT;
