# AppStudyMate Flutter

Client Flutter untuk Firebase atau API AppStudyMate.

## Menjalankan dengan Firebase

Dari root repositori, daftarkan aplikasi Android di Firebase Console
menggunakan package name `com.example.app_studymate_mobile`, lalu aktifkan
Email/Password di Firebase Authentication. Jalankan perintah Flutter dari folder
`apps/mobile`:

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=FIREBASE_ANDROID_APP_ID=1:PROJECT_NUMBER:android:APP_ID
```

Jangan berikan `API_URL` saat memakai Firebase; jika ada, aplikasi akan
mengirim permintaan login ke API, bukan Firebase.

## Menjalankan

Untuk memakai REST API:

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:4000/api
```

Gunakan `http://localhost:4000/api` untuk iOS Simulator atau `http://IP-KOMPUTER:4000/api` untuk perangkat fisik. API Express harus berjalan lebih dulu dengan `npm run dev:api`.

Saat `API_URL` diberikan, aplikasi memakai REST API untuk login, dashboard, serta CRUD jadwal, tugas, dan catatan. Pastikan database MySQL sudah dikonfigurasi dan migrasi Prisma sudah dijalankan. Tanpa `API_URL`, aplikasi tetap memakai mode Firebase atau penyimpanan lokal yang tersedia.
