export function requireRole(...allowedRoles) {
  const allowed = new Set(allowedRoles);

  return function roleCheck(req, res, next) {
    const user = req.user;
    if (!user) return res.status(401).json({ error: "Unauthorized" });
    if (!allowed.has(user.role)) {
      return res.status(403).json({ error: "Forbidden" });
    }
    return next();
  };
}