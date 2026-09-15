import jwt from "jsonwebtoken";
import { Request, Response, NextFunction } from "express";

declare global {
  namespace Express { interface Request { UserId?: string } }
}

export function requireAuth(request: Request, response: Response, next: NextFunction): void {
  const token = request.headers.authorization?.replace("Bearer ", "");
  if (!token) { response.status(401).json({ Message: "Token autentikasi diperlukan" }); return; }
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET ?? "development-secret") as { UserId: string };
    request.UserId = payload.UserId;
    next();
  } catch { response.status(401).json({ Message: "Token tidak valid" }); }
}