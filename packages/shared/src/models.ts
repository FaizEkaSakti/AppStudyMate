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

export interface Course {
  Id: string;
  Name: string;
  Semester: string;
  Year: number;
  CreatedAt: string;
}

export interface Student {
  Id: string;
  CourseId: string;
  StudentNumber: string;
  Name: string;
  Email: string;
  GithubUsername: string;
  CreatedAt: string;
}

export interface Repository {
  Id: string;
  StudentId: string;
  Name: string;
  RepositoryUrl: string;
  Owner: string;
  RepositoryName: string;
  IsActive: boolean;
  LastSyncedAt: string | null;
  CreatedAt: string;
  CommitCount?: number;
}

export interface Commit {
  Id: string;
  RepositoryId: string;
  Sha: string;
  Message: string;
  AuthorName: string;
  AuthorEmail: string;
  CommittedAt: string;
  CommitUrl: string;
  CreatedAt: string;
}

export enum ActivityStatus {
  NO_COMMIT = "NO_COMMIT",
  INACTIVE = "INACTIVE",
  ACTIVE = "ACTIVE"
}

export interface SyncResult {
  RepositoryId: string;
  FetchedCommitCount: number;
  NewCommitCount: number;
  ExistingCommitCount: number;
  LastSyncedAt: string;
  Message: string;
}

export interface CourseSyncResponse {
  Results: Array<SyncResult | { RepositoryId: string; Message: string }>;
  SyncedRepositoryCount: number;
}

export interface StudentProgress {
  StudentId: string;
  StudentName: string;
  StudentNumber: string;
  RepositoryCount: number;
  TotalCommits: number;
  LatestCommitAt: string | null;
  ActivityStatus: ActivityStatus;
}

export interface CourseDashboardResponse {
  Course: Course;
  Summary: {
    TotalStudents: number;
    TotalRepositories: number;
    TotalCommits: number;
    ActiveStudents: number;
    InactiveStudents: number;
    StudentsWithoutCommits: number;
  };
  Students: StudentProgress[];
}

export interface StudentProgressResponse {
  Student: Student;
  Repositories: Array<Repository & { Commits: Commit[] }>;
  TotalCommits: number;
  LatestCommitAt: string | null;
}