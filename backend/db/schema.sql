-- Minimal schema for syncing ReliefRequest JSON blobs.
-- We store the full request JSON in `raw` for flexibility, and key fields for indexing.

CREATE TABLE IF NOT EXISTS requests (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  description TEXT NOT NULL,
  people_count INTEGER NOT NULL,
  location_text TEXT NOT NULL,
  priority TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  raw JSONB NOT NULL
);

CREATE INDEX IF NOT EXISTS requests_updated_at_idx ON requests (updated_at DESC);
CREATE INDEX IF NOT EXISTS requests_status_idx ON requests (status);
CREATE INDEX IF NOT EXISTS requests_type_idx ON requests (type);