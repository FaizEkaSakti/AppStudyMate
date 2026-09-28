# AppStudyMate

AppStudyMate menyatukan alat belajar mahasiswa dan pelacak repositori GitHub. Workspace ini berisi web React, REST API Express, MySQL dengan Prisma, serta aplikasi Flutter yang sudah ada.

## Struktur

```text
apps/
  api/       Express REST API, Prisma schema, migration, dan seed
  mobile/    Aplikasi Flutter untuk mahasiswa
  web/       Dashboard React untuk mahasiswa
packages/
  shared/    Model dan DTO TypeScript yang dipakai API dan web
docker-compose.yml
```

## Prasyarat

- Node.js 20 atau lebih baru
- npm 10 atau lebih baru
- Docker Desktop dengan Docker Compose
- Flutter SDK 3.22 atau lebih baru untuk aplikasi mobile

## Instalasi

1. Salin `.env.example` menjadi `.env` di root project.

```powershell
Copy-Item .env.example .env
```

2. Jalankan MySQL dengan Docker Compose.

```bash
docker compose up -d mysql
```

3. Install dependency, buat Prisma Client, terapkan migration, dan isi data contoh.

```bash
npm install
npm run prisma:generate --workspace @app-studymate/api
npm run db:migrate
npm run db:seed
```

Seed menambahkan satu kelas `Pemrograman Web`, tiga mahasiswa, dan repositori publik contoh. Seed juga mempertahankan data commit yang sudah tersimpan.

## Menjalankan Web dan API

Jalankan setiap perintah pada terminal terpisah dari root project:

```bash
npm run dev:api
```

API berjalan di `http://localhost:4000`.

```bash
npm run dev:web
```

Web berjalan di `http://localhost:5173`. Dashboard hanya membaca database ketika dibuka. Permintaan ke GitHub baru dilakukan setelah tombol sinkronisasi ditekan.

Build semua workspace:

```bash
npm run build
```

## Konfigurasi GitHub

Mahasiswa dapat mengelola kelas, data mahasiswa, dan repositori dari antarmuka tracker. Repositori publik dapat disinkronkan tanpa token. Untuk menaikkan batas permintaan GitHub, isi `GITHUB_TOKEN` di `.env` dengan personal access token yang memiliki akses baca repositori yang diperlukan. Jangan commit file `.env` atau membagikan token.

```dotenv
GITHUB_TOKEN="github_pat_..."
```

Saat sinkronisasi, data commit baru disimpan berdasarkan pasangan `RepositoryId` dan `Sha`. Data commit lama tidak ditimpa atau dihapus. Waktu `LastSyncedAt` berubah setelah permintaan sinkronisasi berhasil.

## API Tracker

Endpoint tracker tidak memakai autentikasi pada versi ini. Route autentikasi dan data mahasiswa lama tetap tersedia untuk aplikasi Flutter.

- `GET|POST /api/courses`
- `GET|PUT|DELETE /api/courses/:Id`
- `GET|POST /api/courses/:CourseId/students`
- `GET|PUT|DELETE /api/students/:Id`
- `GET /api/students/:Id/repositories`
- `POST /api/students/:Id/repositories`
- `PUT|DELETE /api/repositories/:Id`
- `POST /api/repositories/:Id/sync`
- `POST /api/courses/:CourseId/sync`
- `GET /api/courses/:CourseId/dashboard`
- `GET /api/students/:Id/progress`

URL repositori harus memakai format `https://github.com/pemilik/repositori`. Status aktivitas dihitung dari commit terakhir: `ACTIVE` dalam 14 hari terakhir, `INACTIVE` bila lebih lama, dan `NO_COMMIT` bila belum ada commit.

## Aplikasi Flutter

API mahasiswa tetap memakai autentikasi JWT. Jalankan dari folder `apps/mobile`:

```bash
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:4000/api
```

Pelacak GitHub tersedia setelah mahasiswa masuk ke AppStudyMate. Fitur jadwal, tugas, dan catatan tetap tersedia seperti sebelumnya. Android emulator memakai `10.0.2.2`, iOS simulator memakai `localhost`, dan perangkat fisik memakai alamat IP komputer di jaringan lokal.