import type { Schedule as PrismaSchedule, Task as PrismaTask } from "@prisma/client";
import { TaskStatus } from "@app-studymate/shared";
import { mapSchedule, mapTask } from "./mapping.js";

const weekdays = ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"];

export function buildDashboard(tasks: PrismaTask[], schedules: PrismaSchedule[], totalNotes: number, now: Date) {
  const todayName = weekdays[now.getDay()];
  const todayStart = new Date(now);
  todayStart.setHours(0, 0, 0, 0);
  const upcomingLimit = new Date(now);
  upcomingLimit.setDate(upcomingLimit.getDate() + 14);
  const pendingTasks = tasks.filter((task) => task.Status !== TaskStatus.DONE);
  const todaySchedules = schedules
    .filter((schedule) => schedule.Day === todayName)
    .sort((left, right) => left.StartTime.localeCompare(right.StartTime));
  const upcomingTasks = pendingTasks
    .filter((task) => task.Deadline >= todayStart && task.Deadline <= upcomingLimit)
    .sort((left, right) => left.Deadline.getTime() - right.Deadline.getTime())
    .slice(0, 5);

  return {
    Summary: {
      TotalTasks: tasks.length,
      TotalCompletedTasks: tasks.filter((task) => task.Status === TaskStatus.DONE).length,
      TotalPendingTasks: pendingTasks.length,
      TotalOverdueTasks: pendingTasks.filter((task) => task.Deadline < now).length,
      TotalSchedulesToday: todaySchedules.length,
      TotalNotes: totalNotes,
    },
    TodaySchedules: todaySchedules.map(mapSchedule),
    UpcomingTasks: upcomingTasks.map(mapTask),
  };
}