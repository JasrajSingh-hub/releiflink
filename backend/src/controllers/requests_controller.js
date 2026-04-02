import { listRequests, upsertRequest, updateRequestStatus } from "../db/requests_repo.js";

export function createRequestsController({ pool }) {
  return {
    async list(req, res) {
      const all = await listRequests(pool);
      return res.json(all);
    },

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