import { Router } from "express";
import { requireAuth } from "../middleware/auth.js";
import { prisma } from "../lib/prisma.js";
import { buildDashboard } from "../utils/dashboard.js";

export const dashboardRouter = Router();
dashboardRouter.use(requireAuth);
dashboardRouter.get("/", async (request, response, next) => {
  try {
    const [tasks, schedules, notes] = await Promise.all([
      prisma.task.findMany({ where: { UserId: request.UserId } }),
      prisma.schedule.findMany({ where: { UserId: request.UserId }, orderBy: { StartTime: "asc" } }),
      prisma.note.count({ where: { UserId: request.UserId } })
    ]);
    response.json(buildDashboard(tasks, schedules, notes, new Date()));
  } catch (error) { next(error); }
});