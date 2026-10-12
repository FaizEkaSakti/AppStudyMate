import assert from "node:assert/strict";
import test from "node:test";
import { scheduleSchema } from "./schedules.js";

test("schedule input trims required fields and accepts a valid time range", () => {
  const schedule = scheduleSchema.parse({
    CourseName: "  Pemrograman  ",
    Lecturer: "  Ibu Ani  ",
    Day: "  Senin  ",
    StartTime: "08:00",
    EndTime: "09:30",
    Room: "  Lab 1  ",
  });

  assert.equal(schedule.CourseName, "Pemrograman");
  assert.equal(schedule.Lecturer, "Ibu Ani");
  assert.equal(schedule.Day, "Senin");
  assert.equal(schedule.StartTime, "08:00");
  assert.equal(schedule.EndTime, "09:30");
  assert.equal(schedule.Room, "Lab 1");
});

test("schedule input rejects invalid times, empty fields, and non-positive ranges", () => {
  const validSchedule = {
    CourseName: "Pemrograman",
    Lecturer: "Ibu Ani",
    Day: "Senin",
    StartTime: "08:00",
    EndTime: "09:30",
    Room: "Lab 1",
  };

  assert.equal(scheduleSchema.safeParse({ ...validSchedule, StartTime: "25:00" }).success, false);
  assert.equal(scheduleSchema.safeParse({ ...validSchedule, EndTime: "08:00" }).success, false);
  assert.equal(scheduleSchema.safeParse({ ...validSchedule, EndTime: "07:30" }).success, false);
  assert.equal(scheduleSchema.safeParse({ ...validSchedule, CourseName: "   " }).success, false);
  assert.equal(scheduleSchema.safeParse({ ...validSchedule, Lecturer: "   " }).success, false);
  assert.equal(scheduleSchema.safeParse({ ...validSchedule, Day: "   " }).success, false);
  assert.equal(scheduleSchema.safeParse({ ...validSchedule, Room: "   " }).success, false);
});