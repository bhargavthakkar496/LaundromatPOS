BEGIN;

INSERT INTO machines (id, name, type, capacity_kg, price, status)
VALUES
  (10, 'Ironing Station 01', 'Ironing Station', 6, 80.00, 'AVAILABLE'),
  (11, 'Ironing Station 02', 'Ironing Station', 8, 95.00, 'AVAILABLE'),
  (12, 'Ironing Station 03', 'Ironing Station', 10, 110.00, 'MAINTENANCE')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  type = EXCLUDED.type,
  capacity_kg = EXCLUDED.capacity_kg,
  price = EXCLUDED.price,
  status = EXCLUDED.status,
  updated_at = NOW();

COMMIT;
