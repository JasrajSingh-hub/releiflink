import { Router } from "express";

import { requireRole } from "../middleware/require_role.js";

export function requestsRoutes({ controller, auth, authDisabled = false }) {
  const router = Router();

  // Public: used by clients to see the most urgent requests first.
  router.get("/requests", controller.list);

  if (authDisabled) {
    // Dev mode: allow syncing without JWT.
    router.post("/requests", controller.create);
    router.patch("/requests/:id", controller.patch);
    router.put("/requests/:requestId", controller.put);
    router.patch("/requests/:requestId/status", controller.patchStatus);
    return router;
  }

  if (!auth) {
    throw new Error("auth middleware is required when authDisabled=false");
  }

  // Role-based rules:
  // - only "user" can create/update requests
  // - only "volunteer" can update/accept requests (status changes)
  router.post("/requests", auth, requireRole("user"), controller.create);
  router.patch("/requests/:id", auth, requireRole("user"), controller.patch);

  // Compatibility endpoint used by the Flutter sync implementation.
  router.put("/requests/:requestId", auth, requireRole("user"), controller.put);

  router.patch(
    "/requests/:requestId/status",
    auth,
    requireRole("volunteer"),
    controller.patchStatus
  );

  return router;
}