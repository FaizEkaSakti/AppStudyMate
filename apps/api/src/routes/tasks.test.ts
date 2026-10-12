import assert from "node:assert/strict";
import test from "node:test";
import { TaskStatus } from "@app-studymate/shared";
import { taskSchema } from "./tasks.js";

test("task input trims titles and applies defaults", () => {
  const task = taskSchema.parse({
    Title: "  Baca bab 1  ",
    Deadline: "2026-10-20T00:00:00.000Z",
  });

  assert.equal(task.Title, "Baca bab 1");
  assert.equal(task.Description, "");
  assert.equal(task.Status, TaskStatus.TODO);
});

test("task input rejects blank titles, invalid deadlines, and statuses", () => {
  const validTask = {
    Title: "Belajar",
    Deadline: "2026-10-20T00:00:00.000Z",
  };

  assert.equal(taskSchema.safeParse({ ...validTask, Title: "   " }).success, false);
  assert.equal(taskSchema.safeParse({ ...validTask, Deadline: "bukan tanggal" }).success, false);
  assert.equal(taskSchema.safeParse({ ...validTask, Status: "BLOCKED" }).success, false);
});

test("task input accepts each supported workflow status and parses its deadline", () => {
  for (const Status of [TaskStatus.TODO, TaskStatus.IN_PROGRESS, TaskStatus.DONE]) {
    const task = taskSchema.parse({
      Title: "Kumpulkan laporan",
      Deadline: "2026-10-20T00:00:00.000Z",
      Status,
    });

    assert.equal(task.Status, Status);
    assert.ok(task.Deadline instanceof Date);
  }
});