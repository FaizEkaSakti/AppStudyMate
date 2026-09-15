export interface User {
  Id: string;
  Name: string;
  Email: string;
  Nim: string;
  CreatedAt: string;
}

export interface Schedule {
  Id: string;
  UserId: string;
  CourseName: string;
  Lecturer: string;
  Day: string;
  StartTime: string;
  EndTime: string;
  Room: string;
  CreatedAt: string;
}

export interface Task {
  Id: string;
  UserId: string;
  Title: string;
  Description: string;
  Deadline: string;
  Status: TaskStatus;
  CreatedAt: string;
  UpdatedAt: string;
  Urgency: TaskUrgency;
}

export interface Note {
  Id: string;
  UserId: string;
  Title: string;
  Content: string;
  RelatedTaskId: string | null;
  CreatedAt: string;
  UpdatedAt: string;
}

export enum TaskStatus {
  TODO = "TODO",
  IN_PROGRESS = "IN_PROGRESS",
  DONE = "DONE"
}

export enum TaskUrgency {
  OVERDUE = "OVERDUE",
  DUE_SOON = "DUE_SOON",
  ON_TRACK = "ON_TRACK",
  COMPLETED = "COMPLETED"
}

export interface AuthResponse {
  Token: string;
  User: User;
}

export interface DashboardResponse {
  Summary: {
    TotalTasks: number;
    TotalCompletedTasks: number;
    TotalPendingTasks: number;
    TotalOverdueTasks: number;
    TotalSchedulesToday: number;
    TotalNotes: number;
  };
  TodaySchedules: Schedule[];
  UpcomingTasks: Task[];
}

export interface ApiError {
  Message: string;
  Errors?: Record<string, string>;
}