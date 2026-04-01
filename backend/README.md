# ReliefLink Backend (Local Dev)

This is a tiny Node.js backend to support Phase 3 syncing (upload outbox + fetch requests).

## Run (file storage)

- In `releiflink/backend` run: `node server.js`
- It listens on port `8080` by default.
- By default it stores data in a local JSON file (good for quick testing).

## Run (PostgreSQL)

Option A (Docker, recommended):

1) In `releiflink/backend` run: `docker compose up -d`
2) In the same folder, run the backend with `DATABASE_URL`:

   - PowerShell:
     `setx DATABASE_URL "postgres://relieflink:relieflink@localhost:5432/relieflink"`
     (close and reopen the terminal)

   - Then run:
     `node server.js`

Option B (Local Postgres install):

- Set `DATABASE_URL` to your Postgres connection string and run `node server.js`.

Notes:
- When `DATABASE_URL` is set, the backend automatically creates the `requests` table.
- Check which storage is active at `GET /api/health` (it returns `{ storage: "postgres" }` or `{ storage: "file" }`).

## Endpoints

- `GET /api/health`
- `GET /api/requests` -> returns an array of stored requests
- `PUT /api/requests/:requestId` -> create/update full request JSON
- `PATCH /api/requests/:requestId/status` with `{ "status": "inProgress" }`

## Data storage

- File mode: `releiflink/backend/data/requests.json`
- Postgres mode: `requests` table (schema in `releiflink/backend/db/schema.sql`)