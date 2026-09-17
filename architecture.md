# Architecture AppStudyMate

Dokumen ini menjelaskan arsitektur, komponen utama, dan teknologi yang digunakan di project AppStudyMate.

## 1. Ringkasan Arsitektur

Project ini menggunakan pendekatan monorepo dengan tiga area utama:

- `apps/api` : backend REST API menggunakan Node.js + Express + TypeScript
- `apps/mobile` : aplikasi client Android/iOS/desktop web menggunakan Flutter
- `packages/shared` : model shared dan contract response yang dipakai bersama antar layer

Secara umum alur aplikasi adalah:

1. User membuka aplikasi Flutter
2. Flutter memanggil REST API di backend
3. Express server memvalidasi request, otentikasi user, dan mengakses database melalui Prisma
4. Prisma menghubungi MySQL
5. Response dikirim kembali ke mobile app dan diproses UI

---

## 2. Teknologi yang Digunakan

### Frontend / Client

- Flutter
- Dart SDK
- Material Design UI
- `shared_preferences` untuk penyimpanan lokal sederhana
- `firebase_auth`, `firebase_core`, `cloud_firestore` terdaftar di dependency Flutter, walaupun arsitektur inti saat ini masih berfokus pada API custom dan JWT

### Backend

- Node.js
- TypeScript
- Express.js
- Prisma ORM
- MySQL sebagai database utama
- JWT untuk autentikasi
- bcryptjs untuk hash password
- Zod untuk validasi input
- CORS sebagai middleware cross-origin
- dotenv untuk environment variable

### Shared / Contract

- TypeScript package `@app-studymate/shared`
- Interface model bersama: `User`, `Schedule`, `Task`, `Note`, `TaskStatus`, `TaskUrgency`, `DashboardResponse`, `AuthResponse`

### Tools & Dev Environment

- npm workspaces
- Prisma Migrate
- Prisma Seed
- tsx untuk menjalankan TypeScript langsung saat development
- TypeScript compiler (`tsc`)

---

## 3. Struktur Project

```text
AppStudyMate/
├─ apps/
│  ├─ api/
│  │  ├─ prisma/
│  │  │  ├─ schema.prisma
│  │  │  ├─ seed.ts
│  │  │  └─ migrations/
│  │  ├─ src/
│  │  │  ├─ server.ts
│  │  │  ├─ lib/
│  │  │  │  └─ prisma.ts
│  │  │  ├─ middleware/
│  │  │  │  ├─ auth.ts
│  │  │  │  └─ errorHandler.ts
│  │  │  ├─ routes/
│  │  │  │  ├─ auth.ts
│  │  │  │  ├─ dashboard.ts
│  │  │  │  ├─ notes.ts
│  │  │  │  ├─ profile.ts
│  │  │  │  ├─ schedules.ts
│  │  │  │  └─ tasks.ts
│  │  │  └─ utils/
│  │  │     └─ mapping.ts
│  │  ├─ package.json
│  │  └─ tsconfig.json
│  └─ mobile/
│     ├─ lib/
│     ├─ test/
│     ├─ android/
│     ├─ ios/
│     ├─ web/
│     ├─ windows/
│     ├─ pubspec.yaml
│     └─ README.md
├─ packages/
│  └─ shared/
│     ├─ src/
│     │  ├─ index.ts
│     │  └─ models.ts
│     ├─ package.json
│     └─ tsconfig.json
├─ package.json
├─ README.md
├─ architecture.md
└─ tsconfig.json
```

---

## 4. Layer Arsitektur

### 4.1 Presentation Layer (Flutter App)

Folder `apps/mobile` berperan sebagai layer UI dan client logic. Aplikasi ini digunakan untuk:

- autentikasi user
- menampilkan jadwal, tugas, dan catatan
- mengelola data akademik mahasiswa
- komunikasi dengan backend melalui HTTP API

Fungsi UI didesain untuk berinteraksi dengan backend API, bukan langsung ke database.

### 4.2 Application / API Layer (Express)

Folder `apps/api/src` berisi logic bisnis aplikasi. Server dimulai dari `server.ts` dan mem-register route berikut:

- `/api/auth`
- `/api/profile`
- `/api/schedules`
- `/api/tasks`
- `/api/notes`
- `/api/dashboard`

Setiap route dipisahkan berdasarkan domain fitur, lalu middleware seperti auth dan error handler dipakai untuk menjaga konsistensi request/response.

### 4.3 Data Access Layer (Prisma + MySQL)

Prisma digunakan sebagai ORM untuk mengakses MySQL. Model utama didefinisikan di `apps/api/prisma/schema.prisma`.

Struktur data utama:

- `User`
- `Schedule`
- `Task`
- `Note`

Relasi yang digunakan:

- `User` memiliki banyak `Schedule`, `Task`, dan `Note`
- `Task` memiliki banyak `Note`
- `Note` bisa berelasi ke `Task` dengan `RelatedTaskId`
- `onDelete: Cascade` untuk `User` dan `Task`
- `onDelete: SetNull` untuk relasi `Note.RelatedTask`

### 4.4 Shared Contracts Layer

Karena project ini menggunakan workspace monorepo, `packages/shared` dipakai sebagai definisi model bersama. Ini membantu agar:

- frontend dan backend memakai struktur data yang konsisten
- request/response tidak mengandalkan tipe yang berbeda antarlayer
- lebih mudah menjaga API contract

---

## 5. Domain Model

### User

Model `User` memiliki data:

- `Id`
- `Name`
- `Email`
- `PasswordHash`
- `Nim`
- `CreatedAt`

### Schedule

Model `Schedule` menggambarkan jadwal kuliah:

- `CourseName`
- `Lecturer`
- `Day`
- `StartTime`
- `EndTime`
- `Room`
- `UserId`

### Task

Model `Task` mewakili tugas akademik:

- `Title`
- `Description`
- `Deadline`
- `Status` dengan enum `TODO | IN_PROGRESS | DONE`
- `CreatedAt`
- `UpdatedAt`

### Note

Model `Note` digunakan untuk catatan belajar:

- `Title`
- `Content`
- `RelatedTaskId` (opsional)
- `UserId`

---

## 6. Authentication & Security

Arsitektur autentikasi yang digunakan saat ini adalah:

- password di-hash menggunakan `bcryptjs`
- user login mendapatkan JWT
- header `Authorization: Bearer <token>` dipakai untuk route yang butuh autentikasi
- middleware auth di `apps/api/src/middleware/auth.ts` mengecek token

Dengan pola ini, request yang masuk ke API dibatasi hanya user yang login.

---

## 7. API Pattern

Backend mengikuti arsitektur REST sederhana dengan route bersifat feature-based.

### Auth

- `POST /api/auth/register`
- `POST /api/auth/login`

### Profile

- `GET /api/profile`
- `PUT /api/profile`

### Schedule

- `GET /api/schedules`
- `POST /api/schedules`
- `PUT /api/schedules/:Id`
- `DELETE /api/schedules/:Id`

### Task

- `GET /api/tasks`
- `POST /api/tasks`
- `GET /api/tasks/:Id`
- `PUT /api/tasks/:Id`
- `DELETE /api/tasks/:Id`
- `PATCH /api/tasks/:Id/status`

### Notes

- `GET /api/notes`
- `POST /api/notes`
- `GET /api/notes/:Id`
- `PUT /api/notes/:Id`
- `DELETE /api/notes/:Id`

### Dashboard

- `GET /api/dashboard`

Dashboard biasanya menampilkan ringkasan seperti total tugas, tugas selesai, tugas tertunda, tugas terlambat, jadwal hari ini, dan catatan.

---

## 8. Data Flow

### Register / Login

1. User mengirim email, password, username/NIM ke API
2. Express route memvalidasi request
3. Password di-hash dan disimpan ke `User.PasswordHash`
4. JWT dibuat dan dikembalikan ke client

### CRUD Akademik

1. Flutter app mengirim request ke endpoint API
2. `auth` middleware memvalidasi token
3. Router menangani operasi sesuai domain
4. Prisma menjalankan query terhadap MySQL
5. Response dikembalikan dalam format JSON

### Dashboard

1. Backend menghitung ringkasan data berdasarkan user login
2. Query di batasi dengan `UserId`
3. Response berisi ringkasan task, jadwal, dan note

---

## 9. Persistence & Database

Database utama yang dipakai adalah MySQL, dengan konfigurasi menggunakan:

- `datasource db { provider = "mysql" }`
- `url = env("DATABASE_URL")`

Prisma migration dipakai untuk membuat dan menjaga schema database.

Seed data juga disiapkan untuk data awal aplikasi.

---

## 10. Project State & Notes

Beberapa poin penting yang perlu diketahui:

- Project ini masih berada dalam arsitektur monorepo yang cukup terstruktur
- API dan mobile app dipisah secara jelas
- Shared package membantu menjaga contract data antar layer
- Firebase dependency terlihat ada, tetapi pada implementasi yang ada saat ini, core business flow lebih banyak mengandalkan Express + Prisma + JWT
- App ini fokus pada kebutuhan mahasiswa: jadwal, tugas, deadline, dan catatan belajar

---

## 11. Kesimpulan

Arsitektur AppStudyMate terdiri dari:

- Flutter untuk client mobile UI
- Express + TypeScript + Prisma untuk backend API
- MySQL sebagai sistem penyimpanan data
- shared package untuk model dan contract
- JWT + bcrypt untuk autentikasi

Struktur ini cocok untuk aplikasi yang membutuhkan pemisahan jelas antara UI, API, dan data access, serta memudahkan pengembangan fitur baru di masa depan.
