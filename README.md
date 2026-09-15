# AppStudyMate

AppStudyMate adalah aplikasi untuk mahasiswa yang menyatukan jadwal kuliah, tugas, deadline, dan catatan belajar. Project ini memakai Flutter untuk mobile serta Express, Prisma, dan MySQL untuk API.

## Struktur

```text
apps/
	api/       Express REST API dan Prisma
	mobile/    Flutter
packages/
	shared/    model, enum, dan response contract bersama
```

## Prasyarat

- Node.js 20 atau lebih baru
- npm 10 atau lebih baru
- Flutter SDK 3.22 atau lebih baru
- MySQL lokal 8 atau lebih baru

## Instalasi

1. Siapkan MySQL lokal dan buat database `app_studymate`.
2. Salin `.env.example` menjadi `.env` di root project dan isi `DATABASE_URL`.
3. Install dependency API: `npm install`
4. Buat client dan migration Prisma:

```bash
npm run prisma:generate --workspace @app-studymate/api
npm run db:migrate --workspace @app-studymate/api -- --name init
npm run db:seed
```

Seed membuat akun contoh `mahasiswa@example.com` dengan password `password123` dan NIM `20240001`.

## Menjalankan API

```bash
npm run dev:api
```

API berjalan pada `http://localhost:4000`. Semua endpoint selain auth membutuhkan header `Authorization: Bearer <JWT>`.

## Menjalankan Flutter di Android dan iOS

Jalankan API terlebih dahulu dengan `npm run dev:api`, lalu jalankan Flutter dari folder `apps/mobile`.

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:4000/api
```

Android emulator memakai `http://10.0.2.2:4000/api`, iOS simulator memakai `http://localhost:4000/api`, sedangkan perangkat fisik memakai IP komputer di jaringan lokal.

```bash
flutter run --dart-define=API_URL=http://192.168.1.10:4000/api
```

## API

- `POST /api/auth/register`, `POST /api/auth/login`
- `GET|PUT /api/profile`
- `GET|POST /api/schedules`, `PUT|DELETE /api/schedules/:Id`
- `GET|POST /api/tasks`, `GET|PUT|DELETE /api/tasks/:Id`, `PATCH /api/tasks/:Id/status`
- `GET|POST /api/notes`, `GET|PUT|DELETE /api/notes/:Id`
- `GET /api/dashboard`

Property JSON dan shared model menggunakan PascalCase sesuai spesifikasi. Password di-hash dengan bcrypt dan JWT memakai `JWT_SECRET`. Query data akademik selalu dibatasi user yang sedang login. Relasi catatan ke tugas menggunakan `SetNull`, sehingga menghapus tugas tidak menghapus catatan.
