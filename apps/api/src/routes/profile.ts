import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth.js";
import { prisma } from "../lib/prisma.js";
import { mapUser } from "../utils/mapping.js";

export const profileRouter = Router();
profileRouter.use(requireAuth);
profileRouter.get("/", async (request, response, next) => {
  try { const user = await prisma.user.findUniqueOrThrow({ where: { Id: request.UserId } }); response.json(mapUser(user)); } catch (error) { next(error); }
});
profileRouter.put("/", async (request, response, next) => {
  try {
    const input = z.object({ Name: z.string().min(2), Email: z.string().email(), Nim: z.string().min(3) }).parse(request.body);
    const user = await prisma.user.update({ where: { Id: request.UserId }, data: input });
    response.json(mapUser(user));
  } catch (error) { next(error); }
});