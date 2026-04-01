# ReliefLink Backend (Local Dev)

This is a tiny Node.js backend to support Phase 3 syncing (upload outbox + fetch requests).

## Run

- In `releiflink/backend` run: `node server.js`
- It listens on port `8080` by default.

## Endpoints

- `GET /api/health`
- `GET /api/requests` → returns an array of stored requests
- `PUT /api/requests/:requestId` → create/update full request JSON
- `PATCH /api/requests/:requestId/status` with `{ "status": "inProgress" }`

## Data storage

- Requests are stored in `releiflink/backend/data/requests.json` (simple JSON file).

