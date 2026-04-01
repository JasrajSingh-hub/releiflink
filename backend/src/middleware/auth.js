import jwt from "jsonwebtoken";

export function authMiddleware(jwtSecret) {
  return function auth(req, res, next) {
    const header = req.header("Authorization") ?? "";
    const match = header.match(/^Bearer\s+(.+)$/i);
    if (!match) {
      return res.status(401).json({ error: "Missing or invalid Authorization header" });
    }

    const token = match[1];
    try {
      const payload = jwt.verify(token, jwtSecret);
      const userId = payload.userId;
      const role = payload.role;
      if (typeof userId !== "string" || typeof role !== "string") {
        return res.status(401).json({ error: "Invalid token payload" });
      }
      req.user = { id: userId, role };
      return next();
    } catch (e) {
      return res.status(401).json({ error: "Invalid or expired token" });
    }
  };
}