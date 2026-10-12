import assert from "node:assert/strict";
import test from "node:test";
import { TaskStatus as PrismaTaskStatus, type Schedule, type Task } from "@prisma/client";
import { buildDashboard } from "../utils/dashboard.js";

function createTask(
  Id: string,
  Deadline: Date,
  Status: PrismaTaskStatus = PrismaTaskStatus.TODO,
): Task {
  return {
    Id,
    UserId: "user-1",
    Title: Id,
    Description: "",
    Deadline,
    Status,
    CreatedAt: new Date(2026, 9, 1),
    UpdatedAt: new Date(2026, 9, 1),
  };
}

function createSchedule(Id: string, Day: string, StartTime: string): Schedule {
  return {
    Id,
    UserId: "user-1",
    CourseName: Id,
    Lecturer: "Lecturer",
    Day,
    StartTime,
    EndTime: "11:00",
    Room: "A1",
    CreatedAt: new Date(2026, 9, 1),
  };
}

test("dashboard counts pending and overdue tasks and sorts today's schedules", () => {
  const now = new Date(2026, 9, 14, 12);
  const dashboard = buildDashboard(
    [
      createTask("overdue", new Date(2026, 9, 13, 12)),
      createTask("completed", new Date(2026, 9, 12), PrismaTaskStatus.DONE),
      createTask("due-today", new Date(2026, 9, 14, 13)),
      createTask("outside-window", new Date(2026, 9, 29, 12)),
    ],
    [
      createSchedule("late-class", "Rabu", "10:00"),
      createSchedule("other-day", "Kamis", "08:00"),
      createSchedule("early-class", "Rabu", "08:00"),
    ],
    3,
    now,
  );

  assert.deepEqual(dashboard.Summary, {
    TotalTasks: 4,
    TotalCompletedTasks: 1,
    TotalPendingTasks: 3,
    TotalOverdueTasks: 1,
    TotalSchedulesToday: 2,
    TotalNotes: 3,
  });
  assert.deepEqual(dashboard.TodaySchedules.map((schedule) => schedule.Id), ["early-class", "late-class"]);
  assert.deepEqual(dashboard.UpcomingTasks.map((task) => task.Id), ["due-today"]);
});

test("dashboard shows only the five nearest unfinished tasks within fourteen days", () => {
  const now = new Date(2026, 9, 14, 12);
  const tasks = Array.from({ length: 7 }, (_, index) =>
    createTask(`task-${index + 1}`, new Date(2026, 9, 15 + index, 12)),
  );
  tasks.push(createTask("completed-soon", new Date(2026, 9, 15), PrismaTaskStatus.DONE));
  tasks.push(createTask("too-late", new Date(2026, 9, 29, 13)));

  const dashboard = buildDashboard(tasks, [], 0, now);

  assert.deepEqual(
    dashboard.UpcomingTasks.map((task) => task.Id),
    ["task-1", "task-2", "task-3", "task-4", "task-5"],
  );
});