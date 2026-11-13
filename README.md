# HuniGo — Aplikasi Pencari & Sewa Kost

Aplikasi Flutter untuk mencari, memfilter, melihat detail, dan mengajukan sewa kost dengan mudah, terintegrasi dengan backend **NestJS + PostgreSQL** di project terpisah.

## Struktur Project
1. **Frontend (Flutter)**: `/Users/kurniawank/Documents/Projects/hunigo`
2. **Backend API (NestJS + TypeORM)**: `/Users/kurniawank/Documents/Projects/hunigo-api` (atau `kost2u-api`)
3. **Database (PostgreSQL 16 Lokal)**: `/Applications/Postgres.app/Contents/Versions/16/bin` (`localhost:5432`, database: `kost2u_db`)

## Fitur Utama
- **Daftar Kost Lengkap**: Badge *HuniGo Pilihan*, tipe kost (*Putri*, *Putra*, *Campur*), sisa kamar, rating & jumlah ulasan, diskon coret, dan info fasilitas.
- **Pencarian & Filter Lengkap**:
  - Cari berdasarkan nama kost, area/kecamatan, kampus terdekat, atau kota.
  - Filter Kota (*Jakarta Selatan*, *Yogyakarta*, *Bandung*, *Depok*, *Surabaya*, *Malang*).
  - Filter Tipe Kost (*Putri*, *Putra*, *Campur*) & Fasilitas (*AC*, *K. Mandi Dalam*, *WiFi*, *Water Heater*, *Parkir Mobil*, *Kasur*).
  - Pengurutan (*Rekomendasi*, *Harga Terendah*, *Harga Tertinggi*, *Rating Tertinggi*).
- **Halaman Detail Kost**: Galeri foto multi-slide, spesifikasi luas kamar & listrik, fasilitas kamar & umum, peraturan kost, info pemilik, simulasi tanya pemilik (WhatsApp), dan form **Ajukan Sewa**.
- **Integrasi Sewa PostgreSQL**: Pengajuan sewa langsung tersimpan ke tabel `bookings` di PostgreSQL dan dapat dilihat pada tab **Sewa Saya**.
