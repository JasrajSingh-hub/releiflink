import { Router } from "express";

import { requireRole } from "../middleware/require_role.js";

export function requestsRoutes({ controller, auth, authDisabled = false }) {
  const router = Router();

  // Public: used by clients to see the most urgent requests first.
  router.get("/requests", controller.list);

  // Volunteer discovery + task handling
  const addVolunteerRoutes = (mw) => {
    router.get("/requests/nearby", mw, requireRole("volunteer"), controller.nearby);
    router.post("/requests/:id/accept", mw, requireRole("volunteer"), controller.accept);
    router.get("/requests/my-tasks", mw, requireRole("volunteer"), controller.myTasks);
    router.patch(
      "/requests/:requestId/status",
      mw,
      requireRole("volunteer"),
      controller.patchStatus
    );
  };

  if (authDisabled) {
    // Dev mode: allow syncing without JWT.
    router.post("/requests", controller.create);
    router.patch("/requests/:id", controller.patch);
    router.put("/requests/:requestId", controller.put);

    // Dev mode volunteer identity (override via headers if needed).
    const devAuth = (req, _res, next) => {
      const id = req.header("X-Dev-User-Id") ?? "dev-volunteer";
      const role = req.header("X-Dev-Role") ?? "volunteer";
      req.user = { id, role };
      next();
    };

    addVolunteerRoutes(devAuth);
    return router;
  }

  if (!auth) {
    throw new Error("auth middleware is required when authDisabled=false");
  }

  // Role-based rules:
  // - only "user" can create/update requests
  router.post("/requests", auth, requireRole("user"), controller.create);
  router.patch("/requests/:id", auth, requireRole("user"), controller.patch);

  // Compatibility endpoint used by the Flutter sync implementation.
  router.put("/requests/:requestId", auth, requireRole("user"), controller.put);

  // Volunteer-only routes.
  addVolunteerRoutes(auth);

  return router;
}