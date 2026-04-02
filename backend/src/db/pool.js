import { Pool } from "pg";

export function createPool(databaseUrl) {
  const pool = new Pool({ connectionString: databaseUrl });
  return pool;
}