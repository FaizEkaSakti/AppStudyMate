import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth.js";
import { prisma } from "../lib/prisma.js";
import { mapNote } from "../utils/mapping.js";

export const noteRouter = Router();
noteRouter.use(requireAuth);
export const noteSchema = z.object({ Title: z.string().trim().min(1), Content: z.string().trim().min(1), RelatedTaskId: z.string().trim().min(1).nullable().optional() });
export function canLinkRelatedTask(taskOwnerId: string | null | undefined, userId: string): boolean {
	return taskOwnerId === userId;
}
async function hasValidRelatedTask(RelatedTaskId: string | null | undefined, userId: string): Promise<boolean> {
	if (!RelatedTaskId) return true;
	const task = await prisma.task.findUnique({ where: { Id: RelatedTaskId }, select: { UserId: true } });
	return task !== null && canLinkRelatedTask(task.UserId, userId);
}
noteRouter.get("/", async (request, response, next) => { try { const Search = request.query.Search ? String(request.query.Search) : undefined; const rows = await prisma.note.findMany({ where: { UserId: request.UserId, OR: Search ? [{ Title: { contains: Search } }, { Content: { contains: Search } }] : undefined }, orderBy: { UpdatedAt: "desc" } }); response.json(rows.map(mapNote)); } catch (error) { next(error); } });
noteRouter.post("/", async (request, response, next) => { try { const input = noteSchema.parse(request.body); if (!(await hasValidRelatedTask(input.RelatedTaskId, request.UserId!))) { response.status(400).json({ Message: "Tugas terkait tidak ditemukan" }); return; } const row = await prisma.note.create({ data: { ...input, UserId: request.UserId! } }); response.status(201).json(mapNote(row)); } catch (error) { next(error); } });
noteRouter.get("/:Id", async (request, response, next) => { try { const row = await prisma.note.findFirst({ where: { Id: request.params.Id, UserId: request.UserId } }); if (!row) { response.status(404).json({ Message: "Catatan tidak ditemukan" }); return; } response.json(mapNote(row)); } catch (error) { next(error); } });
noteRouter.put("/:Id", async (request, response, next) => { try { const input = noteSchema.parse(request.body); if (!(await hasValidRelatedTask(input.RelatedTaskId, request.UserId!))) { response.status(400).json({ Message: "Tugas terkait tidak ditemukan" }); return; } const row = await prisma.note.updateMany({ where: { Id: request.params.Id, UserId: request.UserId }, data: input }); if (!row.count) { response.status(404).json({ Message: "Catatan tidak ditemukan" }); return; } response.json(mapNote(await prisma.note.findUniqueOrThrow({ where: { Id: request.params.Id } }))); } catch (error) { next(error); } });
noteRouter.delete("/:Id", async (request, response, next) => { try { const row = await prisma.note.deleteMany({ where: { Id: request.params.Id, UserId: request.UserId } }); if (!row.count) { response.status(404).json({ Message: "Catatan tidak ditemukan" }); return; } response.status(204).send(); } catch (error) { next(error); } });