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
      assigned_at TIMESTAMPTZ,
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
    ALTER TABLE requests ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ;

    -- Normalize legacy status values.
    UPDATE requests
    SET status = 'open',
        raw = jsonb_set(raw, '{status}', to_jsonb('open'::text), true)
    WHERE status = 'pending';
    -- Normalize other legacy status variants.
    UPDATE requests
    SET status = 'in_progress',
        raw = jsonb_set(raw, '{status}', to_jsonb('in_progress'::text), true)
    WHERE status IN ('inprogress','in-progress');

    -- Any unknown status is treated as open/unassigned.
    UPDATE requests
    SET status = 'open',
        assigned_to = NULL,
        assigned_at = NULL,
        raw = jsonb_set(
          jsonb_set(
            jsonb_set(raw, '{status}', to_jsonb('open'::text), true),
            '{assignedTo}', 'null'::jsonb, true
          ),
          '{assignedAt}', 'null'::jsonb, true
        )
    WHERE status NOT IN ('open','assigned','in_progress','completed');

    -- Repair inconsistent assignment rows (pre-constraint).
    -- Backfill assigned_to from the JSON blob when present.
    UPDATE requests
    SET assigned_to = NULLIF(raw->>'assignedTo', '')
    WHERE assigned_to IS NULL
      AND NULLIF(raw->>'assignedTo', '') IS NOT NULL;

    -- If a request is marked open but already has an assignee, promote it to assigned.
    UPDATE requests
    SET status = 'assigned',
        raw = jsonb_set(
          jsonb_set(raw, '{status}', to_jsonb('assigned'::text), true),
          '{assignedTo}', to_jsonb(assigned_to::text), true
        )
    WHERE status = 'open' AND assigned_to IS NOT NULL;

    -- If a request is marked assigned/in_progress/completed but has no assignee, demote to open.
    UPDATE requests
    SET status = 'open',
        assigned_at = NULL,
        raw = jsonb_set(
          jsonb_set(
            jsonb_set(raw, '{status}', to_jsonb('open'::text), true),
            '{assignedTo}', 'null'::jsonb, true
          ),
          '{assignedAt}', 'null'::jsonb, true
        )
    WHERE status IN ('assigned','in_progress','completed')
      AND assigned_to IS NULL;

    -- Ensure assigned_at exists for assigned/in_progress/completed rows.
    WITH ts AS (SELECT now() AS t)
    UPDATE requests r
    SET assigned_at = COALESCE(
          r.assigned_at,
          NULLIF(r.raw->>'assignedAt', '')::timestamptz,
          r.updated_at,
          r.created_at,
          ts.t
        ),
        raw = jsonb_set(
          r.raw,
          '{assignedAt}',
          to_jsonb(
            COALESCE(
              r.assigned_at,
              NULLIF(r.raw->>'assignedAt', '')::timestamptz,
              r.updated_at,
              r.created_at,
              ts.t
            )::text
          ),
          true
        )
    FROM ts
    WHERE r.status IN ('assigned','in_progress','completed')
      AND r.assigned_to IS NOT NULL
      AND r.assigned_at IS NULL;

    -- If a request is open and unassigned, assigned_at must be NULL.
    UPDATE requests
    SET assigned_at = NULL,
        raw = jsonb_set(raw, '{assignedAt}', 'null'::jsonb, true)
    WHERE status = 'open' AND assigned_to IS NULL AND assigned_at IS NOT NULL;\n
    -- Prevent inconsistent assignment states.
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'requests_assignment_consistency_chk'
      ) THEN
        ALTER TABLE requests
          ADD CONSTRAINT requests_assignment_consistency_chk
          CHECK (
            (status = 'open' AND assigned_to IS NULL AND assigned_at IS NULL)
            OR
            (status IN ('assigned','in_progress','completed') AND assigned_to IS NOT NULL AND assigned_at IS NOT NULL)
          );
      END IF;
    END $$;

    -- Defense-in-depth: once a request is assigned, prevent reassignment.
    CREATE OR REPLACE FUNCTION requests_prevent_reassignment()
    RETURNS trigger AS $$
    BEGIN
      IF OLD.assigned_to IS NOT NULL AND NEW.assigned_to IS DISTINCT FROM OLD.assigned_to THEN
        RAISE EXCEPTION 'request reassignment not allowed';
      END IF;
      IF OLD.assigned_at IS NOT NULL AND NEW.assigned_at IS DISTINCT FROM OLD.assigned_at THEN
        RAISE EXCEPTION 'request assigned_at immutable';
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'requests_prevent_reassignment_trg') THEN
        CREATE TRIGGER requests_prevent_reassignment_trg
        BEFORE UPDATE OF assigned_to, assigned_at ON requests
        FOR EACH ROW
        EXECUTE FUNCTION requests_prevent_reassignment();
      END IF;
    END $$;
    CREATE INDEX IF NOT EXISTS requests_updated_at_idx ON requests (updated_at DESC);
    CREATE INDEX IF NOT EXISTS requests_status_idx ON requests (status);
    CREATE INDEX IF NOT EXISTS requests_type_idx ON requests (type);
    CREATE INDEX IF NOT EXISTS requests_priority_idx ON requests (priority);
    CREATE INDEX IF NOT EXISTS requests_location_risk_idx ON requests (location_risk);
    CREATE INDEX IF NOT EXISTS requests_assigned_to_idx ON requests (assigned_to);
    CREATE INDEX IF NOT EXISTS requests_assigned_at_idx ON requests (assigned_at);
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