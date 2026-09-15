import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth.js";
import { prisma } from "../lib/prisma.js";
import { mapSchedule } from "../utils/mapping.js";

export const scheduleRouter = Router();
scheduleRouter.use(requireAuth);
const scheduleSchema = z.object({ CourseName: z.string().min(1), Lecturer: z.string().min(1), Day: z.string().min(1), StartTime: z.string(), EndTime: z.string(), Room: z.string().min(1) });
scheduleRouter.get("/", async (request, response, next) => { try { const rows = await prisma.schedule.findMany({ where: { UserId: request.UserId }, orderBy: [{ Day: "asc" }, { StartTime: "asc" }] }); response.json(rows.map(mapSchedule)); } catch (error) { next(error); } });
scheduleRouter.post("/", async (request, response, next) => { try { const row = await prisma.schedule.create({ data: { ...scheduleSchema.parse(request.body), UserId: request.UserId! } }); response.status(201).json(mapSchedule(row)); } catch (error) { next(error); } });
scheduleRouter.put("/:Id", async (request, response, next) => { try { const row = await prisma.schedule.updateMany({ where: { Id: request.params.Id, UserId: request.UserId }, data: scheduleSchema.parse(request.body) }); if (!row.count) { response.status(404).json({ Message: "Jadwal tidak ditemukan" }); return; } const result = await prisma.schedule.findUniqueOrThrow({ where: { Id: request.params.Id } }); response.json(mapSchedule(result)); } catch (error) { next(error); } });
scheduleRouter.delete("/:Id", async (request, response, next) => { try { const row = await prisma.schedule.deleteMany({ where: { Id: request.params.Id, UserId: request.UserId } }); if (!row.count) { response.status(404).json({ Message: "Jadwal tidak ditemukan" }); return; } response.status(204).send(); } catch (error) { next(error); } });