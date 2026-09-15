import path from "node:path";
import { fileURLToPath } from "node:url";
import * as dotenv from "dotenv";
import bcrypt from "bcryptjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.resolve(__dirname, "../../../.env") });

const { Prisma, PrismaClient } = require("@prisma/client");

const prisma = new PrismaClient();

async function seed(): Promise<void> {
  const passwordHash = await bcrypt.hash("password123", 10);
  const user = await prisma.user.upsert({
    where: { Email: "mahasiswa@example.com" },
    update: {},
    create: { Name: "Budi Mahasiswa", Email: "mahasiswa@example.com", Nim: "20240001", PasswordHash: passwordHash }
  });

  await prisma.schedule.deleteMany({ where: { UserId: user.Id } });
  await prisma.task.deleteMany({ where: { UserId: user.Id } });
  await prisma.note.deleteMany({ where: { UserId: user.Id } });
  await prisma.schedule.createMany({ data: [
    { UserId: user.Id, CourseName: "Pemrograman Web", Lecturer: "Dr. Sari", Day: "Senin", StartTime: "08:00", EndTime: "10:00", Room: "Lab A" },
    { UserId: user.Id, CourseName: "Basis Data", Lecturer: "Bpk. Andi", Day: "Rabu", StartTime: "10:00", EndTime: "12:00", Room: "Ruang 204" },
    { UserId: user.Id, CourseName: "Manajemen Proyek", Lecturer: "Ibu Rina", Day: "Jumat", StartTime: "13:00", EndTime: "15:00", Room: "Ruang 301" }
  ] });
  const tasks = await Promise.all([
    prisma.task.create({ data: { UserId: user.Id, Title: "API katalog buku", Description: "Membuat endpoint katalog buku", Deadline: new Date(Date.now() + 86400000 * 2), Status: Prisma.TaskStatus.IN_PROGRESS } }),
    prisma.task.create({ data: { UserId: user.Id, Title: "Laporan basis data", Description: "Menyelesaikan laporan normalisasi", Deadline: new Date(Date.now() + 86400000 * 5), Status: Prisma.TaskStatus.TODO } }),
    prisma.task.create({ data: { UserId: user.Id, Title: "Review proposal", Description: "Review proposal skripsi", Deadline: new Date(Date.now() - 86400000), Status: Prisma.TaskStatus.TODO } }),
    prisma.task.create({ data: { UserId: user.Id, Title: "Presentasi sprint", Description: "Menyiapkan slide presentasi", Deadline: new Date(Date.now() + 86400000 * 7), Status: Prisma.TaskStatus.DONE } }),
    prisma.task.create({ data: { UserId: user.Id, Title: "Baca paper", Description: "Membaca paper machine learning", Deadline: new Date(Date.now() + 86400000 * 12), Status: Prisma.TaskStatus.TODO } })
  ]);
  await prisma.note.createMany({ data: [
    { UserId: user.Id, Title: "Catatan REST API", Content: "REST menggunakan resource dan HTTP method.", RelatedTaskId: tasks[0].Id },
    { UserId: user.Id, Title: "Normalisasi database", Content: "Pastikan setiap atribut bernilai atomik pada 1NF." }
  ] });
}

seed().finally(() => prisma.$disconnect());