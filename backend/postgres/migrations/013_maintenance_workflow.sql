CREATE TABLE IF NOT EXISTS maintenance_records (
  id BIGSERIAL PRIMARY KEY,
  machine_id BIGINT NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
  issue_title TEXT NOT NULL,
  issue_description TEXT,
  priority TEXT NOT NULL DEFAULT 'MEDIUM',
  status TEXT NOT NULL DEFAULT 'MARKED',
  reported_by_name TEXT,
  started_by_name TEXT,
  completed_by_name TEXT,
  reported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  resolution_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS maintenance_records_machine_idx
  ON maintenance_records(machine_id, created_at DESC);

CREATE INDEX IF NOT EXISTS maintenance_records_status_idx
  ON maintenance_records(status, created_at DESC);