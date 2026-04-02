export async function findUserByEmail(pool, email) {
  const { rows } = await pool.query(
    "SELECT id, email, role, password_hash FROM users WHERE email = $1 LIMIT 1",
    [email]
  );
  return rows[0] ?? null;
}