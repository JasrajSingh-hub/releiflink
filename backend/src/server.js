import { config } from "./config.js";
import { createPool } from "./db/pool.js";
import { ensureSchema } from "./db/schema.js";
import { createApp } from "./app.js";
import { createAuthController } from "./controllers/auth_controller.js";
import { createRequestsController } from "./controllers/requests_controller.js";

const pool = createPool(config.databaseUrl);
await ensureSchema(pool);

const controllers = {
  auth: createAuthController({ pool, jwtSecret: config.jwtSecret }),
  requests: createRequestsController({ pool }),
};

const app = createApp({ pool, jwtSecret: config.jwtSecret, controllers });

app.listen(config.port, "0.0.0.0", () => {
  console.log(`Backend listening on http://localhost:${config.port}`);
  console.log(`Health:  http://localhost:${config.port}/api/health`);
});