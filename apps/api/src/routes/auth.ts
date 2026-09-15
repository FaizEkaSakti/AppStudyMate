import { Router } from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { mapUser } from "../utils/mapping.js";

export const authRouter = Router();
const registerSchema = z.object({ Name: z.string().min(2), Email: z.string().email(), Nim: z.string().min(3), Password: z.string().min(6) });
const loginSchema = z.object({ Email: z.string().email(), Password: z.string().min(1) });
const tokenFor = (UserId: string) => jwt.sign({ UserId }, process.env.JWT_SECRET ?? "development-secret", { expiresIn: "7d" });

authRouter.post("/register", async (request, response, next) => {
  try {
    const input = registerSchema.parse(request.body);
    const existing = await prisma.user.findUnique({ where: { Email: input.Email } });
    if (existing) { response.status(409).json({ Message: "Email sudah terdaftar" }); return; }
    const user = await prisma.user.create({ data: { Name: input.Name, Email: input.Email, Nim: input.Nim, PasswordHash: await bcrypt.hash(input.Password, 10) } });
    response.status(201).json({ Token: tokenFor(user.Id), User: mapUser(user) });
  } catch (error) { next(error); }
});

authRouter.post("/login", async (request, response, next) => {
  try {
    const input = loginSchema.parse(request.body);
    const user = await prisma.user.findUnique({ where: { Email: input.Email } });
    if (!user || !(await bcrypt.compare(input.Password, user.PasswordHash))) { response.status(401).json({ Message: "Email atau password salah" }); return; }
    response.json({ Token: tokenFor(user.Id), User: mapUser(user) });
  } catch (error) { next(error); }
});