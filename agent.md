# Agent Guide — Keyloka (Flutter Frontend)

Dokumen ini menjadi panduan utama bagi AI Agent maupun developer yang bekerja pada repositori **Keyloka** (Aplikasi Pencari & Sewa Kost berbasis Flutter).

---

## 1. Gambaran Umum Project
- **Nama Aplikasi**: Keyloka (`com.keyloka.app`)
- **Framework & SDK**: Flutter (Dart SDK `>=3.4.3 <4.0.0`, Material 3)
- **Backend Terkait**: NestJS + TypeORM (`kost2u-api`) yang berjalan di port `3001` dengan database PostgreSQL 16 lokal (`kost2u_db`).
- **Fungsi Utama**:
  - Eksplorasi daftar kost dengan pencarian kata kunci, filter kota, tipe kost (*Putri*, *Putra*, *Campur*), fasilitas, dan pengurutan harga/rating.
  - Manajemen kost favorit (`isFavorite`).
  - Halaman detail kost lengkap dengan galeri foto, spesifikasi kamar, fasilitas, aturan kost, lokasi, kontak WhatsApp pemilik, dan pengajuan sewa.
  - Pengajuan & riwayat sewa kamar (*Booking*) yang tersimpan langsung ke PostgreSQL.
  - Autentikasi Google Sign-In (dengan dukungan Native Android Account Picker via `MethodChannel('com.keyloka.app/google_auth')`) serta manajemen profil & role pengguna (*Pencari Kost* / *Pemilik Kost*).
  - Fitur tambah kost baru khusus untuk pengguna dengan role *Pemilik Kost*.

---

## 2. Struktur Direktori Utama

```text
keyloka/
├── android/                  # Konfigurasi & kode native Android (Kotlin, namespace com.keyloka.app)
├── ios/                      # Konfigurasi & runner iOS (Swift)
├── lib/
│   ├── main.dart             # Entry point aplikasi (KeylokaApp)
│   ├── models/
│   │   ├── booking.dart      # Model data Booking sewa kost
│   │   ├── kost.dart         # Model data Kost beserta serialisasi JSON
│   │   └── user_profile.dart # Model profil user & hasil autentikasi Google
│   ├── screens/
│   │   ├── main_screen.dart        # Navigasi utama (Cari, Favorit, Sewa Saya, Profil) & form tambah kost
│   │   ├── kost_detail_screen.dart # Halaman detail kost & aksi sewa/tanya pemilik
│   │   └── auth_profile_tab.dart   # Tab login Google, registrasi role, & edit profil
│   ├── services/
│   │   ├── api_service.dart  # Klien HTTP ke REST API backend (NestJS)
│   │   └── auth_service.dart # Service autentikasi Google & manajemen sesi aktif
│   ├── utils/
│   │   └── formatters.dart   # Helper format Rupiah, warna tema (AppColors), & utilitas UI
│   └── widgets/
│       ├── booking_sheet.dart # Bottom sheet form pengajuan sewa kost
│       └── kost_card.dart     # Komponen kartu item kost di daftar utama & favorit
├── pubspec.yaml              # Konfigurasi dependensi Flutter
└── README.md                 # Dokumentasi ringkas project
```

---

## 3. Integrasi Backend & Endpoint API

Seluruh komunikasi ke backend dikelola di `lib/services/api_service.dart` menggunakan `dart:io` (`HttpClient`).
- **Default Base URL**: `http://192.168.18.12:3001/api` (dapat diubah saat runtime via `ApiService.setBaseUrl(...)`).
- **Daftar Endpoint**:
  - `GET /api/kosts` — Mengambil daftar kost (mendukung query `search`, `type`, `city`, `facility`, `maxPrice`, `sortBy`).
  - `GET /api/kosts/cities` — Mengambil daftar kota yang tersedia.
  - `GET /api/kosts/filters` — Mengambil opsi filter dinamis (`cities`, `types`, `facilities`).
  - `POST /api/kosts` — Membuat data kost baru.
  - `PATCH /api/kosts/:id/favorite` — Mengubah status favorit kost.
  - `GET /api/bookings` — Mengambil daftar pengajuan sewa.
  - `POST /api/bookings` — Membuat pengajuan sewa baru.
  - `POST /api/auth/google` — Login atau registrasi otomatis pengguna menggunakan akun Google.
  - `PATCH /api/auth/users/:id` — Memperbarui profil pengguna (`name`, `phone`, `role`).

---

## 4. Konvensi & Aturan Pengembangan untuk Agent

1. **Bahasa & UI**:
   - Gunakan Bahasa Indonesia yang natural dan jelas untuk seluruh teks antarmuka pengguna (UI), pesan error, dan snackbar.
   - Gunakan palet warna dari `AppColors` di `lib/utils/formatters.dart` (seperti `AppColors.primaryGreen`) agar tampilan konsisten.
2. **Manajemen State & Jaringan**:
   - State pengguna saat ini disimpan secara reaktif menggunakan `AuthService.currentUserNotifier` (`ValueNotifier<UserProfile?>`).
   - Pastikan setiap pemanggilan async di `StatefulWidget` memeriksa `if (!mounted) return;` sebelum memanggil `setState()` atau menggunakan `BuildContext`.
3. **Autentikasi Android**:
   - Pada Android, `AuthService.signInOrRegisterWithGoogle()` memprioritaskan pemanggilan native account picker melalui `MethodChannel('com.keyloka.app/google_auth')` (`pickGoogleAccount`) di `MainActivity.kt` untuk menghindari kendala `ApiException: 10`, dengan fallback ke paket `google_sign_in`. Jangan menghapus channel ini di `MainActivity.kt`.
4. **Pengujian & Efisiensi Waktu**:
   - **JANGAN melakukan test atau proses inspeksi/verifikasi yang membutuhkan waktu terlalu lama** (hindari *long-running test*, pemindaian berulang di perangkat, atau proses *polling* yang memakan waktu).
   - Utamakan verifikasi cepat seperti `flutter analyze` atau pengecekan langsung yang ringan dan efisien.
5. **Keamanan & Git**:
   - Jangan pernah melakukan commit folder hasil build (`build/`, `.dart_tool/`, `.gradle/`), konfigurasi IDE (`.idea/`, `.vscode/`), maupun file kredensial/keystore (`*.jks`, `*.keystore`, `key.properties`, `.env*`, `google-oauth-client.json`).
6. **Perintah Penting**:
   - Install dependensi: `flutter pub get`
   - Analisis kode / linter: `flutter analyze`
   - Menjalankan aplikasi: `flutter run`
