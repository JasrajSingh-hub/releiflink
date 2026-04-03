import { calculatePriority, normalizeRequestInput } from "../priority/priority_engine.js";

function nowIso() {
  return new Date().toISOString();
}

function priorityRankSql() {
  return "CASE priority WHEN 'Critical' THEN 0 WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END";
}

function defaultTitle(type) {
  return (
    {
      medical: "Medical help",
      food: "Food / Water",
      shelter: "Shelter",
      other: "Help needed",
    }[String(type ?? "other").toLowerCase()] ?? "Help needed"
  );
}

export async function listRequests(pool) {
  const { rows } = await pool.query(
    `SELECT raw FROM requests
     ORDER BY ${priorityRankSql()} ASC, updated_at DESC`
  );
  return rows.map((r) => r.raw);
}

export async function getRequestRowById(pool, requestId) {
  const { rows } = await pool.query(
    "SELECT raw, created_at, status, assigned_to, lat, lng FROM requests WHERE id = $1",
    [requestId]
  );
  return rows[0] ?? null;
}

function normalizeForSave(input, { id, createdAt, updatedAt } = {}) {
  const normalized = normalizeRequestInput(input, { id, createdAt, updatedAt });
  const title = normalized.title?.trim() ? normalized.title.trim() : defaultTitle(normalized.type);
  const peopleCount = input?.peopleCount ?? input?.people_count ?? normalized.peopleAffected ?? 0;

  return {
    ...input,
    ...normalized,
    id: id ?? normalized.id ?? input?.id,
    title,
    // Keep Flutter JSON key as the canonical one.
    peopleCount: Number(peopleCount),
  };
}

export async function createRequest(pool, request) {
  const createdAt = request.createdAt ?? nowIso();
  const updatedAt = nowIso();

  // Requests are created by users. They always start pending and unassigned.
  const base = {
    ...request,
    createdAt,
    updatedAt,
    status: "pending",
    assignedTo: null,
  };

  const savedBase = normalizeForSave(base, { createdAt, updatedAt });
  const { priority } = calculatePriority(savedBase, { now: new Date(updatedAt) });

  const saved = {
    ...savedBase,
    priority,
    status: "pending",
    assignedTo: null,
  };

  await pool.query(
    `INSERT INTO requests (
        id, title, type, description, people_count, location_text, lat, lng,
        priority, status, assigned_to,
        created_at, updated_at, is_life_threatening, location_risk, raw
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,
        $9,$10,$11,
        $12,$13,$14,$15,$16
      )`,
    [
      String(saved.id),
      String(saved.title ?? ""),
      String(saved.type),
      String(saved.description ?? ""),
      Number(saved.peopleAffected ?? 0),
      String(saved.locationText ?? ""),
      saved.lat == null ? null : Number(saved.lat),
      saved.lng == null ? null : Number(saved.lng),
      String(saved.priority),
      String(saved.status ?? "pending"),
      null,
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
  const existingRow = await getRequestRowById(pool, requestId);
  if (!existingRow) return null;

  const existing = existingRow.raw;
  const createdAt = existing?.createdAt ?? existingRow.created_at?.toISOString?.() ?? nowIso();
  const updatedAt = nowIso();

  // Do not allow clients to set priority, assignment, or status directly.
  const {
    priority: _ignored,
    score: _ignored2,
    assignedTo: _ignored3,
    assigned_to: _ignored4,
    assignedToId: _ignored5,
    status: _ignored6,
    ...restPatch
  } = patch ?? {};

  // If a request is already assigned/in progress/completed, keep status + assignment.
  const preservedStatus = String(existingRow.status ?? existing?.status ?? "pending");
  const preservedAssignedTo = existingRow.assigned_to ?? existing?.assignedTo ?? null;

  const merged = {
    ...existing,
    ...restPatch,
    id: requestId,
    createdAt,
    updatedAt,
    status: preservedStatus,
    assignedTo: preservedAssignedTo,
  };

  const savedBase = normalizeForSave(merged, { id: requestId, createdAt, updatedAt });
  const { priority } = calculatePriority(savedBase, { now: new Date(updatedAt) });

  const saved = {
    ...savedBase,
    priority,
    status: preservedStatus,
    assignedTo: preservedAssignedTo,
  };

  await pool.query(
    `UPDATE requests
     SET title = $2,
         type = $3,
         description = $4,
         people_count = $5,
         location_text = $6,
         lat = $7,
         lng = $8,
         priority = $9,
         status = $10,
         assigned_to = $11,
         updated_at = $12,
         is_life_threatening = $13,
         location_risk = $14,
         raw = $15
     WHERE id = $1`,
    [
      requestId,
      String(saved.title ?? ""),
      String(saved.type),
      String(saved.description ?? ""),
      Number(saved.peopleAffected ?? 0),
      String(saved.locationText ?? ""),
      saved.lat == null ? null : Number(saved.lat),
      saved.lng == null ? null : Number(saved.lng),
      String(saved.priority),
      String(saved.status ?? "pending"),
      preservedAssignedTo == null ? null : String(preservedAssignedTo),
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
  const existingRow = await getRequestRowById(pool, requestId);

  const createdAt =
    existingRow?.raw?.createdAt ??
    existingRow?.created_at?.toISOString?.() ??
    body?.createdAt ??
    nowIso();

  const updatedAt = nowIso();

  // Preserve assignment/status if the request is already claimed.
  const preservedStatus = String(existingRow?.status ?? existingRow?.raw?.status ?? "pending");
  const preservedAssignedTo = existingRow?.assigned_to ?? existingRow?.raw?.assignedTo ?? null;

  const merged = {
    ...(existingRow?.raw ?? {}),
    ...(body ?? {}),
    id: requestId,
    createdAt,
    updatedAt,
    status: preservedStatus,
    assignedTo: preservedAssignedTo,
  };

  // Do not allow clients to set priority directly.
  // eslint-disable-next-line no-unused-vars
  const { priority: _ignored, score: _ignored2, ...mergedNoPriority } = merged;

  const savedBase = normalizeForSave(mergedNoPriority, { id: requestId, createdAt, updatedAt });
  const { priority } = calculatePriority(savedBase, { now: new Date(updatedAt) });

  const saved = {
    ...savedBase,
    priority,
    status: preservedStatus,
    assignedTo: preservedAssignedTo,
  };

  await pool.query(
    `INSERT INTO requests (
        id, title, type, description, people_count, location_text, lat, lng,
        priority, status, assigned_to,
        created_at, updated_at, is_life_threatening, location_risk, raw
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,
        $9,$10,$11,
        $12,$13,$14,$15,$16
      )
      ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        type = EXCLUDED.type,
        description = EXCLUDED.description,
        people_count = EXCLUDED.people_count,
        location_text = EXCLUDED.location_text,
        lat = EXCLUDED.lat,
        lng = EXCLUDED.lng,
        priority = EXCLUDED.priority,
        status = EXCLUDED.status,
        assigned_to = COALESCE(requests.assigned_to, EXCLUDED.assigned_to),
        updated_at = EXCLUDED.updated_at,
        is_life_threatening = EXCLUDED.is_life_threatening,
        location_risk = EXCLUDED.location_risk,
        raw = EXCLUDED.raw`,
    [
      requestId,
      String(saved.title ?? ""),
      String(saved.type),
      String(saved.description ?? ""),
      Number(saved.peopleAffected ?? 0),
      String(saved.locationText ?? ""),
      saved.lat == null ? null : Number(saved.lat),
      saved.lng == null ? null : Number(saved.lng),
      String(saved.priority),
      String(saved.status ?? "pending"),
      preservedAssignedTo == null ? null : String(preservedAssignedTo),
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
  const existingRow = await getRequestRowById(pool, requestId);
  if (!existingRow) return null;

  const existing = existingRow.raw;
  const updatedAt = nowIso();

  const merged = { ...existing, status, updatedAt };
  const normalized = normalizeForSave(merged, {
    id: requestId,
    createdAt: existing?.createdAt ?? existingRow.created_at?.toISOString?.() ?? nowIso(),
    updatedAt,
  });
  const { priority } = calculatePriority(normalized, { now: new Date(updatedAt) });

  const saved = { ...merged, ...normalized, priority, assignedTo: existingRow.assigned_to ?? existing?.assignedTo ?? null };

  await pool.query(
    `UPDATE requests
     SET status = $2,
         updated_at = $3::timestamptz,
         priority = $4,
         raw = $5
     WHERE id = $1`,
    [requestId, String(normalized.status), updatedAt, String(priority), saved]
  );

  return saved;
}

function distanceKmSql() {
  // Haversine distance (km) without PostGIS.
  return `(
    2 * 6371 * asin(
      sqrt(
        pow(sin(radians(($1 - lat) / 2)), 2) +
        cos(radians($1)) * cos(radians(lat)) *
        pow(sin(radians(($2 - lng) / 2)), 2)
      )
    )
  )`;
}

export async function listNearbyPendingRequests(pool, { lat, lng, radiusKm, priority, type } = {}) {
  const params = [Number(lat), Number(lng), Number(radiusKm)];
  let i = params.length;

  let where = "WHERE status = 'pending' AND lat IS NOT NULL AND lng IS NOT NULL";
  if (priority) {
    i += 1;
    where += ` AND priority = $${i}`;
    params.push(String(priority));
  }
  if (type) {
    i += 1;
    where += ` AND type = $${i}`;
    params.push(String(type));
  }

  const distanceSql = distanceKmSql();

  const { rows } = await pool.query(
    `SELECT raw, ${distanceSql} AS distance_km
     FROM requests
     ${where}
     AND ${distanceSql} <= $3
     ORDER BY ${priorityRankSql()} ASC, distance_km ASC, updated_at DESC`,
    params
  );

  return rows.map((r) => ({ ...r.raw, distanceKm: Number(r.distance_km) }));
}

export async function acceptRequest(pool, { requestId, volunteerId } = {}) {
  const updatedAt = nowIso();

  const { rows } = await pool.query(
    `UPDATE requests
     SET status = 'assigned',
         assigned_to = $2,
         updated_at = $3::timestamptz,
         raw = jsonb_set(
           jsonb_set(
             jsonb_set(raw, '{status}', to_jsonb('assigned'::text), true),
             '{assignedTo}', to_jsonb($2::text), true
           ),
           '{updatedAt}', to_jsonb($4::text), true
         )
     WHERE id = $1 AND status = 'pending'
     RETURNING raw`,
    [String(requestId), String(volunteerId), updatedAt, updatedAt]
  );

  return rows[0]?.raw ?? null;
}

export async function listVolunteerTasks(pool, { volunteerId } = {}) {
  const { rows } = await pool.query(
    `SELECT raw FROM requests
     WHERE assigned_to = $1
     ORDER BY updated_at DESC`,
    [String(volunteerId)]
  );
  return rows.map((r) => r.raw);
}

export async function updateVolunteerTaskStatus(pool, { requestId, volunteerId, nextStatus } = {}) {
  const existingRow = await getRequestRowById(pool, requestId);
  if (!existingRow) return { ok: false, reason: "not_found" };

  const assignedTo = existingRow.assigned_to ?? existingRow.raw?.assignedTo ?? null;
  if (assignedTo == null || String(assignedTo) !== String(volunteerId)) {
    return { ok: false, reason: "forbidden" };
  }

  const current = String(existingRow.status ?? existingRow.raw?.status ?? "pending");
  const desired = String(nextStatus ?? "").toLowerCase();

  const allowed =
    (current === "assigned" && (desired === "in_progress" || desired === "inprogress")) ||
    (current === "in_progress" && desired === "completed");

  if (!allowed) {
    return { ok: false, reason: "invalid_transition", currentStatus: current };
  }

  const normalizedNext = desired === "inprogress" ? "in_progress" : desired;
  const updatedAt = nowIso();

  const { rows } = await pool.query(
    `UPDATE requests
     SET status = $4,
         updated_at = $5::timestamptz,
         raw = jsonb_set(
           jsonb_set(raw, '{status}', to_jsonb($4::text), true),
           '{updatedAt}', to_jsonb($6::text), true
         )
     WHERE id = $1 AND assigned_to = $2 AND status = $3
     RETURNING raw`,
    [String(requestId), String(volunteerId), String(current), String(normalizedNext), updatedAt, updatedAt]
  );

  const updated = rows[0]?.raw ?? null;
  if (!updated) return { ok: false, reason: "conflict" };

  return { ok: true, request: updated };
}