# ReliefLink Backend (Local Dev)

Node.js + Express + PostgreSQL backend for Phase 3 syncing + minimal JWT login.

## Requirements

- Node.js
- PostgreSQL (Docker recommended)

## Run PostgreSQL (Docker)

- In `releiflink/backend` run: `docker compose up -d`

## Configure env vars

Set these in your terminal/session before starting the backend:

- `DATABASE_URL`
  - Example: `postgres://relieflink:relieflink@localhost:5432/relieflink`
- `JWT_SECRET`
  - Example: `change_me_dev_secret`
- `PORT` (optional)
  - Default: `8080`

PowerShell example:

- `setx DATABASE_URL "postgres://relieflink:relieflink@localhost:5432/relieflink"`
- `setx JWT_SECRET "change_me_dev_secret"`
- Close and reopen the terminal.

## Install deps + run

- In `releiflink/backend` run:
  - `npm install`
  - `npm start`

## Seed a user (no registration endpoint)

1) Generate a bcrypt hash:

- `node scripts/hash-password.js mypassword`

2) Insert a user row into Postgres (example):

- `INSERT INTO users (id, email, password_hash, role) VALUES ('u1', 'user@example.com', '<PASTE_HASH>', 'user');`
- `INSERT INTO users (id, email, password_hash, role) VALUES ('v1', 'vol@example.com', '<PASTE_HASH>', 'volunteer');`

## Auth

### `POST /auth/login`

Body:

- `{ "email": "user@example.com", "password": "mypassword" }`

Response:

- `{ "token": "...", "user": { "id": "...", "email": "...", "role": "user" } }`

Use the token in API calls:

- `Authorization: Bearer <token>`

## Requests API

- `GET /api/health`
- `GET /api/requests` (no auth)

Role-protected:

- `PUT /api/requests/:requestId` (requires role `user`)
- `PATCH /api/requests/:requestId/status` (requires role `volunteer`)

## Data storage

- Postgres tables are created automatically on startup.
- Docker init schema: `releiflink/backend/db/schema.sql`
## Dev mode (disable auth)

If you want syncing to work without JWT while developing, set:

- `AUTH_DISABLED=1`

PowerShell (current terminal only):

- `$env:AUTH_DISABLED="1"`

Then restart the backend. `GET /api/health` will show `authDisabled: true`.

### Volunteer matching (task handling)

Volunteer-only endpoints (requires `Authorization: Bearer <token>` unless `AUTH_DISABLED=1`):

- `GET /api/requests/nearby?lat=12.9716&lng=77.5946&radius=5`
  - Optional: `priority=Critical|High|Medium|Low`, `type=medical|food|shelter|other`
  - Returns pending requests within radius, sorted by priority then distance
- `POST /api/requests/:id/accept`
  - Atomic claim: only works if the request is still `pending`
  - If already claimed, returns `409 { error: "Already assigned" }`
- `GET /api/requests/my-tasks`
  - Lists requests assigned to the logged-in volunteer
- `PATCH /api/requests/:requestId/status`
  - Body: `{ "status": "in_progress" }` or `{ "status": "completed" }`
  - Only the assigned volunteer can update status
  - Allowed transitions: `assigned -> in_progress -> completed`

Dev mode helpers:

- With `AUTH_DISABLED=1`, volunteer endpoints use a dev identity.
  - Default: `id=dev-volunteer`, `role=volunteer`
  - Override with headers:
    - `X-Dev-User-Id: v1`
    - `X-Dev-Role: volunteer`