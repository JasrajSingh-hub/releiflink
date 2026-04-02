import crypto from "node:crypto";

import {
  createRequest,
  listRequests,
  patchRequest,
  upsertRequest,
  updateRequestStatus,
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
      const { priority, score, ...input } = body;

      const id = crypto.randomUUID();
      const saved = await createRequest(pool, { id, ...input });
      return res.status(201).json(saved);
    },

    async list(req, res) {
      const all = await listRequests(pool);
      return res.json(all);
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

      const updated = await updateRequestStatus(pool, requestId, status);
      if (!updated) return res.status(404).json({ error: "Request not found" });
      return res.json(updated);
    },
  };
}