export async function ensureSchema(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS requests (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL DEFAULT '',
      type TEXT NOT NULL,
      description TEXT NOT NULL,
      people_count INTEGER NOT NULL,
      location_text TEXT NOT NULL,
      lat DOUBLE PRECISION,
      lng DOUBLE PRECISION,
      priority TEXT NOT NULL,
      status TEXT NOT NULL,
      assigned_to TEXT,
      created_at TIMESTAMPTZ NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL,
      is_life_threatening BOOLEAN NOT NULL DEFAULT false,
      location_risk TEXT NOT NULL DEFAULT 'low',
      raw JSONB NOT NULL
    );

    -- Upgrade-safe adds (if the table existed before these columns were introduced).
    ALTER TABLE requests ADD COLUMN IF NOT EXISTS title TEXT NOT NULL DEFAULT '';
    ALTER TABLE requests ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION;
    ALTER TABLE requests ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION;
    ALTER TABLE requests ADD COLUMN IF NOT EXISTS assigned_to TEXT;

    CREATE INDEX IF NOT EXISTS requests_updated_at_idx ON requests (updated_at DESC);
    CREATE INDEX IF NOT EXISTS requests_status_idx ON requests (status);
    CREATE INDEX IF NOT EXISTS requests_type_idx ON requests (type);
    CREATE INDEX IF NOT EXISTS requests_priority_idx ON requests (priority);
    CREATE INDEX IF NOT EXISTS requests_location_risk_idx ON requests (location_risk);
    CREATE INDEX IF NOT EXISTS requests_assigned_to_idx ON requests (assigned_to);
    CREATE INDEX IF NOT EXISTS requests_lat_lng_idx ON requests (lat, lng);

    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL CHECK (role IN ('user','volunteer')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE INDEX IF NOT EXISTS users_email_idx ON users (email);
  `);
}