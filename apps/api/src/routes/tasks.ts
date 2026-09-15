import { Router } from "express";
import { z } from "zod";
import { TaskStatus } from "@app-studymate/shared";
import { requireAuth } from "../middleware/auth.js";
import { prisma } from "../lib/prisma.js";
import { mapTask } from "../utils/mapping.js";

export const taskRouter = Router();
taskRouter.use(requireAuth);
const taskSchema = z.object({ Title: z.string().min(1), Description: z.string().default(""), Deadline: z.coerce.date(), Status: z.nativeEnum(TaskStatus).default(TaskStatus.TODO) });
taskRouter.get("/", async (request, response, next) => { try { const { Search, Status, From, To } = request.query; const rows = await prisma.task.findMany({ where: { UserId: request.UserId, Status: Status ? String(Status) as TaskStatus : undefined, Title: Search ? { contains: String(Search) } : undefined, Deadline: From || To ? { gte: From ? new Date(String(From)) : undefined, lte: To ? new Date(String(To)) : undefined } : undefined }, orderBy: { Deadline: "asc" } }); response.json(rows.map(mapTask)); } catch (error) { next(error); } });
taskRouter.post("/", async (request, response, next) => { try { const row = await prisma.task.create({ data: { ...taskSchema.parse(request.body), UserId: request.UserId } }); response.status(201).json(mapTask(row)); } catch (error) { next(error); } });
taskRouter.get("/:Id", async (request, response, next) => { try { const row = await prisma.task.findFirst({ where: { Id: request.params.Id, UserId: request.UserId } }); if (!row) { response.status(404).json({ Message: "Tugas tidak ditemukan" }); return; } response.json(mapTask(row)); } catch (error) { next(error); } });
taskRouter.put("/:Id", async (request, response, next) => { try { const row = await prisma.task.updateMany({ where: { Id: request.params.Id, UserId: request.UserId }, data: taskSchema.parse(request.body) }); if (!row.count) { response.status(404).json({ Message: "Tugas tidak ditemukan" }); return; } response.json(mapTask(await prisma.task.findUniqueOrThrow({ where: { Id: request.params.Id } }))); } catch (error) { next(error); } });
taskRouter.patch("/:Id/status", async (request, response, next) => { try { const status = z.object({ Status: z.nativeEnum(TaskStatus) }).parse(request.body).Status; const row = await prisma.task.updateMany({ where: { Id: request.params.Id, UserId: request.UserId }, data: { Status } }); if (!row.count) { response.status(404).json({ Message: "Tugas tidak ditemukan" }); return; } response.json(mapTask(await prisma.task.findUniqueOrThrow({ where: { Id: request.params.Id } }))); } catch (error) { next(error); } });
taskRouter.delete("/:Id", async (request, response, next) => { try { const row = await prisma.task.deleteMany({ where: { Id: request.params.Id, UserId: request.UserId } }); if (!row.count) { response.status(404).json({ Message: "Tugas tidak ditemukan" }); return; } response.status(204).send(); } catch (error) { next(error); } });