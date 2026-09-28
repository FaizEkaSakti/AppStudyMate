import { NextFunction, Request, Response } from "express";

export function errorHandler(error: unknown, _request: Request, response: Response, _next: NextFunction): void {
  console.error(error);
  if (error && typeof error === "object" && "StatusCode" in error) {
    const statusCode = Number(error.StatusCode);
    response.status(statusCode).json({ Message: error instanceof Error ? error.message : "Permintaan gagal." });
    return;
  }
  if (error && typeof error === "object" && "issues" in error) {
    response.status(400).json({ Message: "Data yang dikirim belum valid.", Errors: error.issues });
    return;
  }
  if (error && typeof error === "object" && "code" in error && error.code === "P2025") {
    response.status(404).json({ Message: "Data tidak ditemukan." });
    return;
  }
  response.status(500).json({ Message: "Terjadi kesalahan pada server" });
}