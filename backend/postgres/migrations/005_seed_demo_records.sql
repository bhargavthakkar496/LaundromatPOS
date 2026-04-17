BEGIN;

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
  (9, 'Dryer 06', 'Dryer', 15, 220.00, 'AVAILABLE'),
  (10, 'Ironing Station 01', 'Ironing Station', 6, 80.00, 'AVAILABLE'),
  (11, 'Ironing Station 02', 'Ironing Station', 8, 95.00, 'AVAILABLE'),
  (12, 'Ironing Station 03', 'Ironing Station', 10, 110.00, 'MAINTENANCE')
ON CONFLICT (id) DO NOTHING;

COMMIT;
