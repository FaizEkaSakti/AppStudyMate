import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth.js";
import { prisma } from "../lib/prisma.js";
import { mapUser } from "../utils/mapping.js";

export const profileRouter = Router();
export const profileSchema = z.object({
  Name: z.string().trim().min(2),
  Email: z.string().trim().toLowerCase().email(),
  Nim: z.string().trim().min(3),
});

profileRouter.use(requireAuth);
profileRouter.get("/", async (request, response, next) => {
  try {
    const user = await prisma.user.findUniqueOrThrow({ where: { Id: request.UserId } });
    response.json(mapUser(user));
  } catch (error) {
    next(error);
  }
});
profileRouter.put("/", async (request, response, next) => {
  try {
    const input = profileSchema.parse(request.body);
    const user = await prisma.user.update({ where: { Id: request.UserId }, data: input });
    response.json(mapUser(user));
  } catch (error) {
    next(error);
  }
});