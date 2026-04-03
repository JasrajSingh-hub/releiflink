import crypto from "node:crypto";

import {
  acceptRequest,
  createRequest,
  listNearbyPendingRequests,
  listRequests,
  listVolunteerTasks,
  patchRequest,
  upsertRequest,
  updateVolunteerTaskStatus,
} from "../db/requests_repo.js";

export function createRequestsController({ pool }) {
  return {
    async create(req, res) {
      const body = req.body ?? {};
      if (typeof body !== "object" || body === null) {
        return res.status(400).json({ error: "Body must be a JSON object" });
      }

      // Do not allow clients to set priority directly.
      // Priority is always computed server-side.
      // eslint-disable-next-line no-unused-vars
      const { priority, score, assignedTo, assigned_to, status, ...input } = body;

      const id = crypto.randomUUID();
      const saved = await createRequest(pool, { id, ...input });
      return res.status(201).json(saved);
    },

    async list(req, res) {
      const all = await listRequests(pool);
      return res.json(all);
    },

    async nearby(req, res) {
      const lat = Number(req.query.lat);
      const lng = Number(req.query.lng);
      const radiusKm = Number(req.query.radius);

      if (!Number.isFinite(lat) || !Number.isFinite(lng) || !Number.isFinite(radiusKm)) {
        return res.status(400).json({ error: "lat, lng, radius are required" });
      }
      if (radiusKm <= 0 || radiusKm > 500) {
        return res.status(400).json({ error: "radius must be between 0 and 500 km" });
      }

      const priority = typeof req.query.priority === "string" ? req.query.priority : undefined;
      const type = typeof req.query.type === "string" ? req.query.type : undefined;

      const rows = await listNearbyPendingRequests(pool, { lat, lng, radiusKm, priority, type });
      return res.json(rows);
    },

    async accept(req, res) {
      const requestId = req.params.id;
      const volunteerId = req.user?.id;

      if (!requestId) return res.status(400).json({ error: "Missing id" });
      if (typeof volunteerId !== "string" || volunteerId.length === 0) {
        return res.status(401).json({ error: "Missing auth" });
      }

      const result = await acceptRequest(pool, { requestId, volunteerId });
      if (result.ok) return res.status(200).json(result.request);

      if (result.reason === "not_found") {
        return res.status(404).json({ error: "Request not found" });
      }

      console.warn(
        `accept conflict requestId=${requestId} volunteerId=${volunteerId} status=${result.status ?? ""} assignedTo=${result.assignedTo ?? ""}`
      );
      return res.status(409).json({ error: "Request already accepted" });
    },

    async myTasks(req, res) {
      const volunteerId = req.user?.id;
      if (typeof volunteerId !== "string" || volunteerId.length === 0) {
        return res.status(401).json({ error: "Missing auth" });
      }
      const tasks = await listVolunteerTasks(pool, { volunteerId });
      return res.json(tasks);
    },

    async patch(req, res) {
      const id = req.params.id;
      const body = req.body ?? {};
      if (!id) return res.status(400).json({ error: "Missing id" });
      if (typeof body !== "object" || body === null) {
        return res.status(400).json({ error: "Body must be a JSON object" });
      }

      const updated = await patchRequest(pool, id, body);
      if (!updated) return res.status(404).json({ error: "Request not found" });
      return res.json(updated);
    },

    // Compatibility endpoint used by the Flutter sync implementation.
    async put(req, res) {
      const requestId = req.params.requestId;
      const body = req.body;
      if (!requestId) return res.status(400).json({ error: "Missing requestId" });
      if (typeof body !== "object" || body === null) {
        return res.status(400).json({ error: "Body must be a JSON object" });
      }

      const saved = await upsertRequest(pool, requestId, body);
      return res.json(saved);
    },

    async patchStatus(req, res) {
      const requestId = req.params.requestId;
      const { status } = req.body ?? {};
      if (typeof status !== "string" || status.length === 0) {
        return res.status(400).json({ error: "Missing status" });
      }

      const volunteerId = req.user?.id;
      if (typeof volunteerId !== "string" || volunteerId.length === 0) {
        return res.status(401).json({ error: "Missing auth" });
      }

      const result = await updateVolunteerTaskStatus(pool, {
        requestId,
        volunteerId,
        nextStatus: status,
      });

      if (result.ok) return res.json(result.request);

      if (result.reason === "not_found") {
        return res.status(404).json({ error: "Request not found" });
      }
      if (result.reason === "forbidden") {
        return res.status(403).json({ error: "Not your task" });
      }
      if (result.reason === "invalid_transition") {
        return res.status(409).json({
          error: "Invalid status transition",
          currentStatus: result.currentStatus,
        });
      }

      return res.status(409).json({ error: "Status update conflict" });
    },
  };
}