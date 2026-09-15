import { Note as PrismaNote, Schedule as PrismaSchedule, Task as PrismaTask, User as PrismaUser } from "@prisma/client";
import { Note, Schedule, Task, TaskStatus, TaskUrgency, User } from "@app-studymate/shared";

export const mapUser = (value: PrismaUser): User => ({ Id: value.Id, Name: value.Name, Email: value.Email, Nim: value.Nim, CreatedAt: value.CreatedAt.toISOString() });
export const mapSchedule = (value: PrismaSchedule): Schedule => ({ ...value, CreatedAt: value.CreatedAt.toISOString() });
export const mapTask = (value: PrismaTask): Task => ({ ...value, Status: value.Status as TaskStatus, Deadline: value.Deadline.toISOString(), CreatedAt: value.CreatedAt.toISOString(), UpdatedAt: value.UpdatedAt.toISOString(), Urgency: getUrgency(value.Status as TaskStatus, value.Deadline) });
export const mapNote = (value: PrismaNote): Note => ({ ...value, CreatedAt: value.CreatedAt.toISOString(), UpdatedAt: value.UpdatedAt.toISOString() });
export function getUrgency(status: TaskStatus, deadline: Date): TaskUrgency {
  if (status === TaskStatus.DONE) return TaskUrgency.COMPLETED;
  const days = (deadline.getTime() - Date.now()) / 86400000;
  return days < 0 ? TaskUrgency.OVERDUE : days <= 3 ? TaskUrgency.DUE_SOON : TaskUrgency.ON_TRACK;
}