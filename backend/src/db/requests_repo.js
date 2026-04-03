import { calculatePriority, normalizeRequestInput } from "../priority/priority_engine.js";

function nowIso() {
  return new Date().toISOString();
}

function priorityRankSql() {
  return "CASE priority WHEN 'Critical' THEN 0 WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END";
}

export async function listRequests(pool) {
  const { rows } = await pool.query(
    `SELECT raw FROM requests
     ORDER BY ${priorityRankSql()} ASC, updated_at DESC`
  );
  return rows.map((r) => r.raw);
}

export async function getRequestRawById(pool, requestId) {
  const { rows } = await pool.query(
    "SELECT raw, created_at FROM requests WHERE id = $1",
    [requestId]
  );
  return rows[0] ?? null;
}

export async function createRequest(pool, request) {
  const createdAt = request.createdAt ?? nowIso();
  const updatedAt = nowIso();

  const normalized = normalizeRequestInput(request, { createdAt, updatedAt });
  const { priority } = calculatePriority(normalized, { now: new Date(updatedAt) });

  const saved = {
    ...request,
    ...normalized,
    createdAt,
    updatedAt,
    priority,
  };

  await pool.query(
    `INSERT INTO requests (
        id, type, description, people_count, location_text, priority, status,
        created_at, updated_at, is_life_threatening, location_risk, raw
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,
        $8,$9,$10,$11,$12
      )`,
    [
      String(saved.id),
      String(saved.type),
      String(saved.description ?? ""),
      Number(saved.peopleAffected ?? 0),
      String(saved.locationText ?? ""),
      String(saved.priority),
      String(saved.status ?? "pending"),
      createdAt,
      updatedAt,
      Boolean(saved.isLifeThreatening),
      String(saved.locationRisk),
      saved,
    ]
  );

  return saved;
}

export async function patchRequest(pool, requestId, patch) {
  const existingRow = await getRequestRawById(pool, requestId);
  if (!existingRow) return null;

  const existing = existingRow.raw;
  const createdAt = existing?.createdAt ?? existingRow.created_at?.toISOString?.() ?? nowIso();
  const updatedAt = nowIso();

  // Do not allow clients to set priority directly.
  const { priority: _ignored, score: _ignored2, ...restPatch } = patch ?? {};

  const merged = {
    ...existing,
    ...restPatch,
    id: requestId,
    createdAt,
    updatedAt,
  };

  const normalized = normalizeRequestInput(merged, { id: requestId, createdAt, updatedAt });
  const { priority } = calculatePriority(normalized, { now: new Date(updatedAt) });

  const saved = {
    ...merged,
    ...normalized,
    priority,
  };

  await pool.query(
    `UPDATE requests
     SET type = $2,
         description = $3,
         people_count = $4,
         location_text = $5,
         priority = $6,
         status = $7,
         updated_at = $8,
         is_life_threatening = $9,
         location_risk = $10,
         raw = $11
     WHERE id = $1`,
    [
      requestId,
      String(saved.type),
      String(saved.description ?? ""),
      Number(saved.peopleAffected ?? 0),
      String(saved.locationText ?? ""),
      String(saved.priority),
      String(saved.status ?? "pending"),
      updatedAt,
      Boolean(saved.isLifeThreatening),
      String(saved.locationRisk),
      saved,
    ]
  );

  return saved;
}

export async function upsertRequest(pool, requestId, body) {
  // Compatibility for existing sync endpoint (PUT /api/requests/:requestId)
  // Priority is always computed server-side and cannot be overridden.
  const existingRow = await getRequestRawById(pool, requestId);
  const createdAt =
    existingRow?.raw?.createdAt ??
    existingRow?.created_at?.toISOString?.() ??
    body?.createdAt ??
    nowIso();

  const updatedAt = nowIso();

  const merged = {
    ...(existingRow?.raw ?? {}),
    ...(body ?? {}),
    id: requestId,
    createdAt,
    updatedAt,
  };

  const normalized = normalizeRequestInput(merged, { id: requestId, createdAt, updatedAt });
  const { priority } = calculatePriority(normalized, { now: new Date(updatedAt) });

  const saved = {
    ...merged,
    ...normalized,
    priority,
  };

  await pool.query(
    `INSERT INTO requests (
        id, type, description, people_count, location_text, priority, status,
        created_at, updated_at, is_life_threatening, location_risk, raw
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,
        $8,$9,$10,$11,$12
      )
      ON CONFLICT (id) DO UPDATE SET
        type = EXCLUDED.type,
        description = EXCLUDED.description,
        people_count = EXCLUDED.people_count,
        location_text = EXCLUDED.location_text,
        priority = EXCLUDED.priority,
        status = EXCLUDED.status,
        updated_at = EXCLUDED.updated_at,
        is_life_threatening = EXCLUDED.is_life_threatening,
        location_risk = EXCLUDED.location_risk,
        raw = EXCLUDED.raw`,
    [
      requestId,
      String(saved.type),
      String(saved.description ?? ""),
      Number(saved.peopleAffected ?? 0),
      String(saved.locationText ?? ""),
      String(saved.priority),
      String(saved.status ?? "pending"),
      createdAt,
      updatedAt,
      Boolean(saved.isLifeThreatening),
      String(saved.locationRisk),
      saved,
    ]
  );

  return saved;
}

export async function updateRequestStatus(pool, requestId, status) {
  const existingRow = await getRequestRawById(pool, requestId);
  if (!existingRow) return null;

  const existing = existingRow.raw;
  const updatedAt = nowIso();

  const merged = { ...existing, status, updatedAt };
  const normalized = normalizeRequestInput(merged, {
    id: requestId,
    createdAt: existing?.createdAt ?? existingRow.created_at?.toISOString?.() ?? nowIso(),
    updatedAt,
  });
  const { priority } = calculatePriority(normalized, { now: new Date(updatedAt) });

  const saved = { ...merged, ...normalized, priority };

  await pool.query(
    `UPDATE requests
     SET status = $2,
         updated_at = $3,
         priority = $4,
         raw = $5
     WHERE id = $1`,
    [requestId, status, updatedAt, String(priority), saved]
  );

  return saved;
}