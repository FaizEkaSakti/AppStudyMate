# AppStudyMate Flutter

Client Flutter untuk API AppStudyMate.

## Menjalankan

```bash
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:4000/api
```

Gunakan `http://localhost:4000/api` untuk iOS Simulator atau `http://IP-KOMPUTER:4000/api` untuk perangkat fisik. API Express harus berjalan lebih dulu dengan `npm run dev:api`.

Saat `API_URL` diberikan, aplikasi memakai REST API untuk login, dashboard, serta CRUD jadwal, tugas, dan catatan. Pastikan database MySQL sudah dikonfigurasi dan migrasi Prisma sudah dijalankan. Tanpa `API_URL`, aplikasi tetap memakai mode Firebase atau penyimpanan lokal yang tersedia.
