import express from "express";

import { authRoutes } from "./routes/auth_routes.js";
import { requestsRoutes } from "./routes/requests_routes.js";
import { authMiddleware } from "./middleware/auth.js";

export function createApp({ pool, jwtSecret, controllers, authDisabled = false }) {
  const app = express();

  app.use(express.json({ limit: "2mb" }));

  // Minimal request logging (no bodies, no auth headers).
  app.use((req, res, next) => {
    const start = Date.now();
    res.on("finish", () => {
      const ms = Date.now() - start;
      console.log(`${res.statusCode} ${req.method} ${req.originalUrl} (${ms}ms)`);
    });
    next();
  });

  // Minimal CORS (for dev/testing).
  app.use((req, res, next) => {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET,PUT,PATCH,POST,OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
    if (req.method === "OPTIONS") return res.status(204).end();
    return next();
  });

  app.get("/api/health", (req, res) => {
    res.json({ ok: true, authDisabled });
  });

  const auth = authDisabled ? null : authMiddleware(jwtSecret);

  app.use("/auth", authRoutes(controllers.auth));
  app.use(
    "/api",
    requestsRoutes({ controller: controllers.requests, auth, authDisabled })
  );

  // Basic error handler
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    console.error(err);
    res.status(500).json({ error: "Internal server error" });
  });

  return app;
}