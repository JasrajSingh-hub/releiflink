import { Pool } from "pg";

export function canUsePostgres() {
  return Boolean(process.env.DATABASE_URL);
}

export function createPool() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error("DATABASE_URL is not set");
  const pool = new Pool({ connectionString: url });
  return pool;
}

export async function ensureSchema(pool) {
  await pool.query(`
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
  `);
}

export async function listRequests(pool) {
  const { rows } = await pool.query(
    "SELECT raw FROM requests ORDER BY updated_at DESC"
  );
  return rows.map((r) => r.raw);
}

export async function upsertRequest(pool, requestId, body) {
  const createdAt = body.createdAt ?? new Date().toISOString();
  const updatedAt = body.updatedAt ?? new Date().toISOString();

  const saved = { ...body, id: requestId, createdAt, updatedAt };

  await pool.query(
    `INSERT INTO requests (
        id, type, description, people_count, location_text, priority, status,
        created_at, updated_at, raw
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,
        $8,$9,$10
      )
      ON CONFLICT (id) DO UPDATE SET
        type = EXCLUDED.type,
        description = EXCLUDED.description,
        people_count = EXCLUDED.people_count,
        location_text = EXCLUDED.location_text,
        priority = EXCLUDED.priority,
        status = EXCLUDED.status,
        updated_at = EXCLUDED.updated_at,
        raw = EXCLUDED.raw
    `,
    [
      requestId,
      String(saved.type ?? ""),
      String(saved.description ?? ""),
      Number(saved.peopleCount ?? saved.people_count ?? 0),
      String(saved.locationText ?? saved.location_text ?? ""),
      String(saved.priority ?? ""),
      String(saved.status ?? "pending"),
      createdAt,
      updatedAt,
      saved,
    ]
  );

  return saved;
}

export async function updateStatus(pool, requestId, status) {
  const { rows } = await pool.query(
    "SELECT raw FROM requests WHERE id = $1",
    [requestId]
  );
  if (rows.length === 0) return null;

  const existing = rows[0].raw;
  const updated = { ...existing, status, updatedAt: new Date().toISOString() };

  await pool.query(
    `UPDATE requests
     SET status = $2,
         updated_at = $3,
         raw = $4
     WHERE id = $1`,
    [requestId, status, updated.updatedAt, updated]
  );

  return updated;
}