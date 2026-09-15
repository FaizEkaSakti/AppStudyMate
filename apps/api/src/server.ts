import "dotenv/config";
import express from "express";
import cors from "cors";
import { authRouter } from "./routes/auth.js";
import { profileRouter } from "./routes/profile.js";
import { scheduleRouter } from "./routes/schedules.js";
import { taskRouter } from "./routes/tasks.js";
import { noteRouter } from "./routes/notes.js";
import { dashboardRouter } from "./routes/dashboard.js";
import { errorHandler } from "./middleware/errorHandler.js";

const app = express();
app.use(cors());
app.use(express.json());
app.use("/api/auth", authRouter);
app.use("/api/profile", profileRouter);
app.use("/api/schedules", scheduleRouter);
app.use("/api/tasks", taskRouter);
app.use("/api/notes", noteRouter);
app.use("/api/dashboard", dashboardRouter);
app.use(errorHandler);

const port = Number(process.env.API_PORT ?? 4000);
app.listen(port, () => console.log(`AppStudyMate API berjalan di port ${port}`));