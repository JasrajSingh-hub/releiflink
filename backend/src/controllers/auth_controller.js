import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";

import { findUserByEmail } from "../db/users_repo.js";

export function createAuthController({ pool, jwtSecret }) {
  return {
    async login(req, res) {
      const { email, password } = req.body ?? {};
      if (typeof email !== "string" || typeof password !== "string") {
        return res.status(400).json({ error: "email and password are required" });
      }

      const normalizedEmail = email.trim().toLowerCase();
      const user = await findUserByEmail(pool, normalizedEmail);
      if (!user) {
        return res.status(401).json({ error: "Invalid credentials" });
      }

      const ok = await bcrypt.compare(password, user.password_hash);
      if (!ok) {
        return res.status(401).json({ error: "Invalid credentials" });
      }

      const token = jwt.sign(
        { userId: user.id, role: user.role },
        jwtSecret,
        { expiresIn: "7d" }
      );

      return res.json({
        token,
        user: {
          id: user.id,
          email: user.email,
          role: user.role,
        },
      });
    },
  };
}