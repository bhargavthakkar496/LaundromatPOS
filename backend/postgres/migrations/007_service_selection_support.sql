BEGIN;

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS selected_services TEXT[] NOT NULL DEFAULT ARRAY['Washing', 'Drying']::TEXT[],
  ADD COLUMN IF NOT EXISTS ironing_machine_id BIGINT REFERENCES machines(id);

ALTER TABLE active_order_sessions
  ADD COLUMN IF NOT EXISTS selected_services TEXT[] NOT NULL DEFAULT ARRAY['Washing', 'Drying']::TEXT[],
  ADD COLUMN IF NOT EXISTS ironing_machine_id BIGINT REFERENCES machines(id);

ALTER TABLE active_order_sessions
  ALTER COLUMN wash_option DROP NOT NULL,
  ALTER COLUMN washer_machine_id DROP NOT NULL,
  ALTER COLUMN dryer_machine_id DROP NOT NULL;

UPDATE orders
SET selected_services = CASE
  WHEN dryer_machine_id IS NOT NULL THEN ARRAY['Washing', 'Drying']::TEXT[]
  ELSE ARRAY['Washing']::TEXT[]
END
WHERE selected_services IS NULL
   OR array_length(selected_services, 1) IS NULL;

UPDATE active_order_sessions
SET selected_services = CASE
  WHEN dryer_machine_id IS NOT NULL THEN ARRAY['Washing', 'Drying']::TEXT[]
  ELSE ARRAY['Washing']::TEXT[]
END
WHERE selected_services IS NULL
   OR array_length(selected_services, 1) IS NULL;

COMMIT;
