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