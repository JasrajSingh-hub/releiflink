function parseCreatedAt(createdAt) {
  if (!createdAt) return null;
  const d = new Date(createdAt);
  return Number.isNaN(d.getTime()) ? null : d;
}

export function calculatePriority(request, { now = new Date() } = {}) {
  const type = String(request.type ?? "other").toLowerCase();
  const peopleAffected = Number(request.peopleAffected ?? request.peopleCount ?? 0);
  const isLifeThreatening = Boolean(request.isLifeThreatening);
  const locationRisk = String(request.locationRisk ?? "low").toLowerCase();
  const createdAtDate = parseCreatedAt(request.createdAt) ?? now;

  let score = 0;
  if (isLifeThreatening) score += 50;
  if (type === "medical") score += 20;
  if (peopleAffected > 5) score += 20;
  if (now.getTime() - createdAtDate.getTime() > 60 * 60 * 1000) score += 10;
  if (locationRisk === "high") score += 10;

  let priority = "Low";
  if (score >= 70) priority = "Critical";
  else if (score >= 50) priority = "High";
  else if (score >= 30) priority = "Medium";

  return { score, priority };
}

export function normalizeRequestInput(input, { id, createdAt, updatedAt } = {}) {
  const type = String(input?.type ?? "other").toLowerCase();
  const peopleAffected = Number(
    input?.peopleAffected ?? input?.peopleCount ?? input?.people_count ?? 0
  );

  const isLifeThreatening = Boolean(input?.isLifeThreatening ?? input?.is_life_threatening);
  const locationRisk = String(
    input?.locationRisk ?? input?.location_risk ?? "low"
  ).toLowerCase();

  const normalized = {
    id: id ?? input?.id,
    type: type === "medical" || type === "food" || type === "shelter" || type === "other"
      ? type
      : "other",
    peopleAffected: Number.isFinite(peopleAffected) ? peopleAffected : 0,
    isLifeThreatening,
    locationRisk: locationRisk === "low" || locationRisk === "medium" || locationRisk === "high"
      ? locationRisk
      : "low",
    createdAt: createdAt ?? input?.createdAt ?? input?.created_at,
    updatedAt: updatedAt ?? input?.updatedAt ?? input?.updated_at,
  };

  return normalized;
}

