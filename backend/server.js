import http from "node:http";
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  canUsePostgres,
  createPool,
  ensureSchema,
  listRequests,
  upsertRequest,
  updateStatus,
} from "./db/postgres.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const DATA_DIR = join(__dirname, "data");
const DATA_FILE = join(DATA_DIR, "requests.json");

function ensureDataDir() {
  if (!existsSync(DATA_DIR)) mkdirSync(DATA_DIR, { recursive: true });
}

function loadStore() {
  ensureDataDir();
  if (!existsSync(DATA_FILE)) return {};
  try {
    const raw = readFileSync(DATA_FILE, "utf8");
    if (!raw.trim()) return {};
    const parsed = JSON.parse(raw);
    return typeof parsed === "object" && parsed ? parsed : {};
  } catch {
    return {};
  }
}

function saveStore(store) {
  ensureDataDir();
  writeFileSync(DATA_FILE, JSON.stringify(store, null, 2), "utf8");
}

let store = loadStore(); // { [requestId]: requestJson }
let pgPool = null;
let storageMode = "file"; // 'file' | 'postgres'

function json(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,PUT,PATCH,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  });
  res.end(payload);
}

function notFound(res) {
  json(res, 404, { error: "Not found" });
}

function badRequest(res, message) {
  json(res, 400, { error: message });
}

function methodNotAllowed(res) {
  json(res, 405, { error: "Method not allowed" });
}

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 2_000_000) {
        reject(new Error("Body too large"));
      }
    });
    req.on("end", () => {
      if (!body.trim()) return resolve({});
      try {
        resolve(JSON.parse(body));
      } catch (e) {
        reject(e);
      }
    });
    req.on("error", reject);
  });
}

function nowIso() {
  return new Date().toISOString();
}

function isObject(v) {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function parsePath(url) {
  const u = new URL(url, "http://localhost");
  return { pathname: u.pathname, searchParams: u.searchParams };
}

const server = http.createServer(async (req, res) => {
  const { pathname } = parsePath(req.url ?? "/");

  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET,PUT,PATCH,OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    });
    res.end();
    return;
  }

  if (req.method === "GET" && pathname === "/api/health") {
    json(res, 200, { ok: true, storage: storageMode });
    return;
  }

  if (req.method === "GET" && pathname === "/api/requests") {
    if (pgPool) {
      const all = await listRequests(pgPool);
      json(res, 200, all);
      return;
    }
    json(res, 200, Object.values(store));
    return;
  }

  const putMatch = pathname.match(/^\/api\/requests\/([^/]+)$/);
  if (putMatch) {
    const requestId = decodeURIComponent(putMatch[1]);
    if (req.method !== "PUT") return methodNotAllowed(res);

    let body;
    try {
      body = await readJsonBody(req);
    } catch (e) {
      return badRequest(res, "Invalid JSON body");
    }
    if (!isObject(body)) return badRequest(res, "Body must be a JSON object");

    if (pgPool) {
      const saved = await upsertRequest(pgPool, requestId, body);
      json(res, 200, saved);
      return;
    }

    const existing = store[requestId];
    const createdAt = existing?.createdAt ?? body.createdAt ?? nowIso();
    const updatedAt = body.updatedAt ?? nowIso();

    const saved = { ...body, id: requestId, createdAt, updatedAt };
    store[requestId] = saved;
    saveStore(store);
    json(res, 200, saved);
    return;
  }

  const patchMatch = pathname.match(/^\/api\/requests\/([^/]+)\/status$/);
  if (patchMatch) {
    const requestId = decodeURIComponent(patchMatch[1]);
    if (req.method !== "PATCH") return methodNotAllowed(res);

    let body;
    try {
      body = await readJsonBody(req);
    } catch (e) {
      return badRequest(res, "Invalid JSON body");
    }
    if (!isObject(body)) return badRequest(res, "Body must be a JSON object");
    const status = body.status;
    if (typeof status !== "string" || status.length === 0) {
      return badRequest(res, "Missing `status`");
    }

    if (pgPool) {
      const updated = await updateStatus(pgPool, requestId, status);
      if (!updated) return json(res, 404, { error: "Request not found" });
      json(res, 200, updated);
      return;
    }

    const existing = store[requestId];
    if (!existing) return json(res, 404, { error: "Request not found" });
    const updated = { ...existing, status, updatedAt: nowIso() };
    store[requestId] = updated;
    saveStore(store);
    json(res, 200, updated);
    return;
  }

  notFound(res);
});

const PORT = Number.parseInt(process.env.PORT ?? "8080", 10);

async function start() {
  if (canUsePostgres()) {
    try {
      pgPool = createPool();
      await ensureSchema(pgPool);
      storageMode = "postgres";
      console.log("Storage: PostgreSQL (DATABASE_URL detected)");
    } catch (e) {
      pgPool = null;
      storageMode = "file";
      console.warn("Postgres init failed; falling back to file storage.");
      console.warn(String(e));
    }
  }

  server.listen(PORT, "0.0.0.0", () => {
    console.log(`ReliefLink backend listening on http://localhost:${PORT}`);
    console.log(`Health:  http://localhost:${PORT}/api/health`);
    console.log(`API base: http://localhost:${PORT}/api`);
  });
}

start();