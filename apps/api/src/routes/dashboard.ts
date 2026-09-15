import { Router } from "express";
import { requireAuth } from "../middleware/auth.js";
import { prisma } from "../lib/prisma.js";
import { mapSchedule, mapTask } from "../utils/mapping.js";
import { TaskStatus } from "@app-studymate/shared";

export const dashboardRouter = Router();
dashboardRouter.use(requireAuth);
dashboardRouter.get("/", async (request, response, next) => {
  try {
    const now = new Date(); const end = new Date(now); end.setHours(23, 59, 59, 999);
    const start = new Date(now); start.setHours(0, 0, 0, 0);
    const [tasks, schedules, notes] = await Promise.all([
      prisma.task.findMany({ where: { UserId: request.UserId } }),
      prisma.schedule.findMany({ where: { UserId: request.UserId }, orderBy: { StartTime: "asc" } }),
      prisma.note.count({ where: { UserId: request.UserId } })
    ]);
    const todayName = ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"][now.getDay()];
    const pending = tasks.filter((task) => task.Status !== TaskStatus.DONE);
    const overdue = pending.filter((task) => task.Deadline < now);
    response.json({ Summary: { TotalTasks: tasks.length, TotalCompletedTasks: tasks.filter((task) => task.Status === TaskStatus.DONE).length, TotalPendingTasks: pending.length, TotalOverdueTasks: overdue.length, TotalSchedulesToday: schedules.filter((item) => item.Day === todayName).length, TotalNotes: notes }, TodaySchedules: schedules.filter((item) => item.Day === todayName).map(mapSchedule), UpcomingTasks: tasks.filter((task) => task.Deadline >= start && task.Deadline <= new Date(now.getTime() + 14 * 86400000)).sort((a, b) => a.Deadline.getTime() - b.Deadline.getTime()).slice(0, 5).map(mapTask) });
  } catch (error) { next(error); }
});