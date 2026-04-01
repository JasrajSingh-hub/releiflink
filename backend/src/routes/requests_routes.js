import { Router } from "express";

import { requireRole } from "../middleware/require_role.js";

export function requestsRoutes({ controller, auth }) {
  const router = Router();

  router.get("/requests", controller.list);

  // Role-based rules:
  // - only "user" can create/update requests
  // - only "volunteer" can update/accept requests (status changes)
  router.put("/requests/:requestId", auth, requireRole("user"), controller.put);
  router.patch(
    "/requests/:requestId/status",
    auth,
    requireRole("volunteer"),
    controller.patchStatus
  );

  return router;
}