export function getEnv(name, { required = false, fallback = undefined } = {}) {
  const val = process.env[name];
  if (val && String(val).length > 0) return String(val);
  if (required) throw new Error(`Missing required env var: ${name}`);
  return fallback;
}

function parseBool(v, fallback = false) {
  if (v == null) return fallback;
  const s = String(v).trim().toLowerCase();
  if (["1", "true", "yes", "y", "on"].includes(s)) return true;
  if (["0", "false", "no", "n", "off"].includes(s)) return false;
  return fallback;
}

export const config = {
  port: Number.parseInt(getEnv("PORT", { fallback: "8080" }), 10),
  databaseUrl: getEnv("DATABASE_URL", { required: true }),
  jwtSecret: getEnv("JWT_SECRET", { required: true }),
  authDisabled: parseBool(getEnv("AUTH_DISABLED", { fallback: "0" })),
};
