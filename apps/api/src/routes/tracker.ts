import { ActivityStatus } from "@app-studymate/shared";
import { Router } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";

export const trackerRouter = Router();

const courseSchema = z.object({
  Name: z.string().trim().min(1),
  Semester: z.string().trim().min(1),
  Year: z.coerce.number().int().min(2000).max(2200)
});
const studentSchema = z.object({
  StudentNumber: z.string().trim().min(1),
  Name: z.string().trim().min(1),
  Email: z.string().trim().email(),
  GithubUsername: z.string().trim().min(1)
});
const repositorySchema = z.object({ Name: z.string().trim().min(1), RepositoryUrl: z.string().trim().url(), IsActive: z.boolean().default(true) });
const githubRepositoryUrl = /^https?:\/\/github\.com\/([^/]+)\/([^/?#]+)\/?$/i;
const ActivityWindowMs = 14 * 24 * 60 * 60 * 1000;

type GithubCommit = {
  sha: string;
  html_url: string;
  commit: {
    message: string;
    author: { name: string | null; email: string | null; date: string } | null;
  };
};

function parseRepositoryUrl(value: string): { Owner: string; RepositoryName: string } | null {
  const match = value.match(githubRepositoryUrl);
  if (!match) return null;
  const RepositoryName = match[2].replace(/\.git$/i, "");
  if (!RepositoryName) return null;
  return { Owner: match[1], RepositoryName };
}

function activityStatus(latestCommitAt: Date | null): ActivityStatus {
  if (!latestCommitAt) return ActivityStatus.NO_COMMIT;
  return Date.now() - latestCommitAt.getTime() > ActivityWindowMs ? ActivityStatus.INACTIVE : ActivityStatus.ACTIVE;
}

function mapRepository(repository: {
  Id: string; StudentId: string; Name: string; RepositoryUrl: string; Owner: string;
  RepositoryName: string; IsActive: boolean; LastSyncedAt: Date | null; CreatedAt: Date; _count?: { Commits: number };
}) {
  return {
    Id: repository.Id,
    StudentId: repository.StudentId,
    Name: repository.Name,
    RepositoryUrl: repository.RepositoryUrl,
    Owner: repository.Owner,
    RepositoryName: repository.RepositoryName,
    IsActive: repository.IsActive,
    LastSyncedAt: repository.LastSyncedAt?.toISOString() ?? null,
    CreatedAt: repository.CreatedAt.toISOString(),
    ...(repository._count ? { CommitCount: repository._count.Commits } : {})
  };
}

async function synchronizeRepository(repositoryId: string) {
  const repository = await prisma.repository.findUnique({ where: { Id: repositoryId } });
  if (!repository) throw Object.assign(new Error("Repositori tidak ditemukan"), { StatusCode: 404 });

  const commits: GithubCommit[] = [];
  for (let page = 1; ; page += 1) {
    const headers: Record<string, string> = {
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28"
    };
    if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
    let githubResponse: Response;
    try {
      githubResponse = await fetch(
        `https://api.github.com/repos/${encodeURIComponent(repository.Owner)}/${encodeURIComponent(repository.RepositoryName)}/commits?per_page=100&page=${page}`,
        { headers }
      );
    } catch {
      throw Object.assign(new Error("GitHub tidak dapat dijangkau. Periksa koneksi internet lalu coba lagi."), { StatusCode: 502 });
    }
    if (!githubResponse.ok) {
      const rateLimited = githubResponse.status === 429 ||
        (githubResponse.status === 403 && githubResponse.headers.get("x-ratelimit-remaining") === "0");
      if (rateLimited) {
        throw Object.assign(new Error("Batas permintaan GitHub tercapai. Tambahkan GITHUB_TOKEN atau coba lagi nanti."), { StatusCode: 429 });
      }
      if (githubResponse.status === 404) {
        throw Object.assign(new Error("Repositori tidak ditemukan atau bersifat privat. Pastikan URL repositori publik benar."), { StatusCode: 404 });
      }
      if (githubResponse.status === 401) {
        throw Object.assign(new Error("Token GitHub tidak valid. Periksa konfigurasi GITHUB_TOKEN."), { StatusCode: 401 });
      }
      throw Object.assign(new Error(`GitHub menolak permintaan (HTTP ${githubResponse.status}).`), { StatusCode: 502 });
    }
    const pageCommits = await githubResponse.json() as GithubCommit[];
    commits.push(...pageCommits);
    if (pageCommits.length < 100) break;
  }

  const lastSyncedAt = new Date();
  const insert = await prisma.$transaction(async (transaction) => {
    const result = await transaction.commit.createMany({
      data: commits.map((item) => ({
        RepositoryId: repository.Id,
        Sha: item.sha,
        Message: item.commit.message,
        AuthorName: item.commit.author?.name ?? "Tidak diketahui",
        AuthorEmail: item.commit.author?.email ?? "",
        CommittedAt: new Date(item.commit.author?.date ?? lastSyncedAt),
        CommitUrl: item.html_url
      })),
      skipDuplicates: true
    });
    await transaction.repository.update({ where: { Id: repository.Id }, data: { LastSyncedAt: lastSyncedAt } });
    return result;
  });

  return {
    RepositoryId: repository.Id,
    FetchedCommitCount: commits.length,
    NewCommitCount: insert.count,
    ExistingCommitCount: commits.length - insert.count,
    LastSyncedAt: lastSyncedAt.toISOString(),
    Message: insert.count ? `${insert.count} commit baru berhasil disimpan.` : "Tidak ada commit baru."
  };
}

trackerRouter.get("/courses", async (_request, response, next) => {
  try {
    const courses = await prisma.course.findMany({ orderBy: [{ Year: "desc" }, { Name: "asc" }] });
    response.json(courses.map((course) => ({ ...course, CreatedAt: course.CreatedAt.toISOString() })));
  } catch (error) { next(error); }
});

trackerRouter.post("/courses", async (request, response, next) => {
  try {
    const course = await prisma.course.create({ data: courseSchema.parse(request.body) });
    response.status(201).json({ ...course, CreatedAt: course.CreatedAt.toISOString() });
  } catch (error) { next(error); }
});

trackerRouter.get("/courses/:Id", async (request, response, next) => {
  try {
    const course = await prisma.course.findUnique({ where: { Id: request.params.Id } });
    if (!course) { response.status(404).json({ Message: "Kelas tidak ditemukan." }); return; }
    response.json({ ...course, CreatedAt: course.CreatedAt.toISOString() });
  } catch (error) { next(error); }
});

trackerRouter.put("/courses/:Id", async (request, response, next) => {
  try {
    const course = await prisma.course.update({ where: { Id: request.params.Id }, data: courseSchema.parse(request.body) });
    response.json({ ...course, CreatedAt: course.CreatedAt.toISOString() });
  } catch (error) { next(error); }
});

trackerRouter.delete("/courses/:Id", async (request, response, next) => {
  try {
    await prisma.course.delete({ where: { Id: request.params.Id } });
    response.status(204).send();
  } catch (error) { next(error); }
});

trackerRouter.get("/courses/:CourseId/students", async (request, response, next) => {
  try {
    const students = await prisma.student.findMany({ where: { CourseId: request.params.CourseId }, orderBy: { Name: "asc" } });
    response.json(students.map((student) => ({ ...student, CreatedAt: student.CreatedAt.toISOString() })));
  } catch (error) { next(error); }
});

trackerRouter.post("/courses/:CourseId/students", async (request, response, next) => {
  try {
    const student = await prisma.student.create({
      data: { ...studentSchema.parse(request.body), CourseId: request.params.CourseId }
    });
    response.status(201).json({ ...student, CreatedAt: student.CreatedAt.toISOString() });
  } catch (error) { next(error); }
});

trackerRouter.get("/students/:Id", async (request, response, next) => {
  try {
    const student = await prisma.student.findUnique({ where: { Id: request.params.Id } });
    if (!student) { response.status(404).json({ Message: "Mahasiswa tidak ditemukan." }); return; }
    response.json({ ...student, CreatedAt: student.CreatedAt.toISOString() });
  } catch (error) { next(error); }
});

trackerRouter.get("/students/:Id/repositories", async (request, response, next) => {
  try {
    const repositories = await prisma.repository.findMany({
      where: { StudentId: request.params.Id }, include: { _count: { select: { Commits: true } } }, orderBy: { CreatedAt: "desc" }
    });
    response.json(repositories.map(mapRepository));
  } catch (error) { next(error); }
});

trackerRouter.post("/students/:Id/repositories", async (request, response, next) => {
  try {
    const data = repositorySchema.parse(request.body);
    const parsedUrl = parseRepositoryUrl(data.RepositoryUrl);
    if (!parsedUrl) { response.status(400).json({ Message: "URL harus berbentuk https://github.com/pemilik/repositori." }); return; }
    const repository = await prisma.repository.create({
      data: { ...data, ...parsedUrl, StudentId: request.params.Id }, include: { _count: { select: { Commits: true } } }
    });
    response.status(201).json(mapRepository(repository));
  } catch (error) { next(error); }
});

trackerRouter.put("/students/:Id", async (request, response, next) => {
  try {
    const student = await prisma.student.update({ where: { Id: request.params.Id }, data: studentSchema.parse(request.body) });
    response.json({ ...student, CreatedAt: student.CreatedAt.toISOString() });
  } catch (error) { next(error); }
});

trackerRouter.delete("/students/:Id", async (request, response, next) => {
  try {
    await prisma.student.delete({ where: { Id: request.params.Id } });
    response.status(204).send();
  } catch (error) { next(error); }
});

trackerRouter.put("/repositories/:Id", async (request, response, next) => {
  try {
    const data = repositorySchema.parse(request.body);
    const parsedUrl = parseRepositoryUrl(data.RepositoryUrl);
    if (!parsedUrl) { response.status(400).json({ Message: "URL harus berbentuk https://github.com/pemilik/repositori." }); return; }
    const repository = await prisma.repository.update({
      where: { Id: request.params.Id }, data: { ...data, ...parsedUrl }, include: { _count: { select: { Commits: true } } }
    });
    response.json(mapRepository(repository));
  } catch (error) { next(error); }
});

trackerRouter.delete("/repositories/:Id", async (request, response, next) => {
  try {
    await prisma.repository.delete({ where: { Id: request.params.Id } });
    response.status(204).send();
  } catch (error) { next(error); }
});

trackerRouter.post("/repositories/:Id/sync", async (request, response, next) => {
  try { response.json(await synchronizeRepository(request.params.Id)); }
  catch (error) { next(error); }
});

trackerRouter.post("/courses/:CourseId/sync", async (request, response, next) => {
  try {
    const course = await prisma.course.findUnique({ where: { Id: request.params.CourseId }, select: { Id: true } });
    if (!course) { response.status(404).json({ Message: "Kelas tidak ditemukan." }); return; }
    const repositories = await prisma.repository.findMany({
      where: { IsActive: true, Student: { CourseId: request.params.CourseId } }, select: { Id: true }
    });
    const results: Array<Awaited<ReturnType<typeof synchronizeRepository>> | { RepositoryId: string; Message: string }> = [];
    for (const { Id } of repositories) {
      try { results.push(await synchronizeRepository(Id)); }
      catch (error) { results.push({ RepositoryId: Id, Message: error instanceof Error ? error.message : "Sinkronisasi gagal." }); }
    }
    response.json({ Results: results, SyncedRepositoryCount: results.filter((result) => "NewCommitCount" in result).length });
  } catch (error) { next(error); }
});

trackerRouter.get("/courses/:CourseId/dashboard", async (request, response, next) => {
  try {
    const course = await prisma.course.findUnique({ where: { Id: request.params.CourseId } });
    if (!course) { response.status(404).json({ Message: "Kelas tidak ditemukan." }); return; }
    const students = await prisma.student.findMany({
      where: { CourseId: course.Id },
      include: {
        Repositories: {
          include: {
            Commits: { orderBy: { CommittedAt: "desc" }, take: 1 },
            _count: { select: { Commits: true } }
          }
        }
      },
      orderBy: { Name: "asc" }
    });
    const progress = students.map((student) => {
      const totalCommits = student.Repositories.reduce((total, repository) => total + repository._count.Commits, 0);
      const latestCommitAt = student.Repositories.flatMap((repository) => repository.Commits)
        .reduce<Date | null>((latest, commit) => !latest || commit.CommittedAt > latest ? commit.CommittedAt : latest, null);
      return {
        StudentId: student.Id,
        StudentName: student.Name,
        StudentNumber: student.StudentNumber,
        RepositoryCount: student.Repositories.length,
        TotalCommits: totalCommits,
        LatestCommitAt: latestCommitAt?.toISOString() ?? null,
        ActivityStatus: activityStatus(latestCommitAt)
      };
    });
    const repositoryCount = await prisma.repository.count({ where: { Student: { CourseId: course.Id } } });
    const commitCount = await prisma.commit.count({ where: { Repository: { Student: { CourseId: course.Id } } } });
    response.json({
      Course: { ...course, CreatedAt: course.CreatedAt.toISOString() },
      Summary: {
        TotalStudents: students.length,
        TotalRepositories: repositoryCount,
        TotalCommits: commitCount,
        ActiveStudents: progress.filter((student) => student.ActivityStatus === ActivityStatus.ACTIVE).length,
        InactiveStudents: progress.filter((student) => student.ActivityStatus === ActivityStatus.INACTIVE).length,
        StudentsWithoutCommits: progress.filter((student) => student.ActivityStatus === ActivityStatus.NO_COMMIT).length
      },
      Students: progress
    });
  } catch (error) { next(error); }
});

trackerRouter.get("/students/:Id/progress", async (request, response, next) => {
  try {
    const student = await prisma.student.findUnique({
      where: { Id: request.params.Id },
      include: { Repositories: { include: { Commits: { orderBy: { CommittedAt: "desc" } } } } }
    });
    if (!student) { response.status(404).json({ Message: "Mahasiswa tidak ditemukan." }); return; }
    const commits = student.Repositories.flatMap((repository) => repository.Commits);
    const latest = commits.reduce<Date | null>((value, commit) => !value || commit.CommittedAt > value ? commit.CommittedAt : value, null);
    response.json({
      Student: {
        Id: student.Id, CourseId: student.CourseId, StudentNumber: student.StudentNumber,
        Name: student.Name, Email: student.Email, GithubUsername: student.GithubUsername, CreatedAt: student.CreatedAt.toISOString()
      },
      Repositories: student.Repositories.map((repository) => ({
        ...mapRepository(repository),
        Commits: repository.Commits.map((commit) => ({ ...commit, CommittedAt: commit.CommittedAt.toISOString(), CreatedAt: commit.CreatedAt.toISOString() }))
      })),
      TotalCommits: commits.length,
      LatestCommitAt: latest?.toISOString() ?? null
    });
  } catch (error) { next(error); }
});