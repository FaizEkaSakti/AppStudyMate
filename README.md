# AppStudyMate

AppStudyMate membantu mahasiswa mengatur jadwal kuliah, tugas, deadline, dan catatan belajar. Workspace ini berisi REST API Express, MySQL dengan Prisma, serta aplikasi Flutter.

## Struktur

```text
apps/
  api/       Express REST API, Prisma schema, migration, dan seed
  mobile/    Aplikasi Flutter untuk mahasiswa
packages/
  shared/    Model dan DTO TypeScript yang dipakai API
docker-compose.yml
```

## MVP Version 1: User Stories dan Acceptance Criteria

1. **Kelola tugas.** Mahasiswa dapat menyimpan tugas dengan judul, deadline, deskripsi, dan status. Judul wajib berisi teks setelah spasi tepi dihapus, deadline harus valid, dan status awal adalah `TODO`.
2. **Kelola jadwal kuliah.** Mahasiswa dapat mencatat mata kuliah, dosen, hari, ruangan, serta rentang waktu. Field wajib tidak boleh kosong, format jam adalah `HH:mm`, dan jam selesai harus setelah jam mulai.
3. **Buat catatan belajar.** Mahasiswa dapat menyimpan judul dan isi catatan yang tidak kosong. Catatan boleh terkait tugas, tetapi tugas tersebut harus dimiliki oleh pengguna yang sama.
4. **Daftar dan masuk akun.** Mahasiswa mengirim nama, NIM, email, dan password; nama/NIM dirapikan dan email disimpan dalam huruf kecil. Input tidak memenuhi batas minimum atau format email ditolak.
5. **Pantau dashboard.** Dashboard menghitung tugas selesai, pending, dan overdue secara terpisah; hanya jadwal hari ini yang ditampilkan; tugas mendatang yang belum selesai diurutkan berdasarkan deadline dan dibatasi lima item dalam 14 hari.

## Unit tests

Test aturan bisnis MVP API berada di `apps/api/src/routes/`:
`auth.test.ts`, `tasks.test.ts`, `schedules.test.ts`, `notes.test.ts`, dan
`dashboard.test.ts`. Test mobile berada di `apps/mobile/test/`, termasuk
`dashboard_data_test.dart`.

Jalankan semua unit test dari root repository:

```sh
npm test --workspace @app-studymate/api
cd apps/mobile
flutter test
```

# AppStudyMate
1. Problem Statement

Mahasiswa sering mengalami kesulitan dalam mengatur jadwal kuliah, tugas, deadline, dan kegiatan belajar. Informasi tersebut biasanya tersebar di berbagai aplikasi seperti kalender, catatan, dan chat sehingga mudah terlupakan. Dibutuhkan satu aplikasi mobile yang dapat membantu mahasiswa mengatur kegiatan akademik dengan lebih terorganisir.

2. Target User

Target utama:

Mahasiswa
Pelajar tingkat akhir
Mahasiswa yang memiliki banyak tugas dan jadwal kuliah

Target sekunder:

Dosen atau admin sebagai pengelola informasi akademik (opsional)

3. App Value

StudyMate memberikan nilai dengan menyediakan satu tempat untuk mengelola aktivitas akademik. Pengguna dapat melihat jadwal, mencatat tugas, mengetahui deadline, membuat catatan, dan memantau progress belajar tanpa harus menggunakan banyak aplikasi.

Value utama:

Jadwal lebih terorganisir
Tugas lebih mudah dikelola
Mengurangi risiko lupa deadline
Catatan belajar tersimpan dalam satu aplikasi
Progress belajar lebih mudah dipantau

4. Must-Have Features

Fitur yang wajib ada pada versi awal:

Login & Register
Dashboard
Class Schedule
Task Management
Task Deadline
Task Status
Study Notes
Profile
Search & Filter
CRUD data tugas dan jadwal

5. In Scope

Fitur yang akan dikerjakan dalam project:

Registrasi dan login pengguna
Dashboard mahasiswa
Menampilkan jadwal kuliah
Menambah, mengedit, dan menghapus jadwal
Menampilkan daftar tugas
Menambah, mengedit, dan menghapus tugas
Menentukan deadline tugas
Mengubah status tugas
Membuat dan mengelola catatan belajar
Melihat profile pengguna
Menyimpan data menggunakan database
Menghubungkan aplikasi mobile dengan REST API

6. Out of Scope

Fitur yang belum termasuk dalam versi project ini:

Video conference
Chat antar mahasiswa
Sistem pembayaran
Integrasi Google Classroom
Integrasi sistem akademik kampus
AI tutor
Marketplace buku
Sistem ujian online
Notifikasi WhatsApp
Fitur untuk mengelola seluruh administrasi kampus


Tugas p4
https://docs.google.com/document/d/12iTj2jHD9Vm1ASM3gxiXem6WuGD5KjhBmpEdluKWdXY/edit?usp=sharing

Tugas p5
https://docs.google.com/document/d/1_st2LbMxO7IKU-AG6hhNTBw-i3JJN4Uv8RTMV2sd-DI/edit?usp=sharing

Tugas p6
https://docs.google.com/document/d/1PQOXnzPewHYa4ZpkaDbkVUQXYYMiFt_8s46lruofNA8/edit?usp=sharing




