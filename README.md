# SIMPEG Mobile — Modul Cuti

Aplikasi mobile berbasis Flutter untuk pengajuan dan persetujuan cuti pegawai, dengan alur persetujuan berjenjang (multi-role). Dikembangkan sebagai bagian dari Kerja Praktik di Pengadilan Negeri/PHI/Tipikor Bengkulu Kelas IA (Juli–Agustus 2025) dan dibangun ulang pada 2026 sebagai proyek portofolio.

## Tampilan Aplikasi

### 1. Login, Beranda, dan Profil

Pegawai masuk melalui halaman login, lalu diarahkan ke beranda yang menampilkan ringkasan cuti, fitur pencarian, dan informasi saldo cuti. Data diri pengguna dapat dilihat di halaman profil.

<p>
  <img src="screenshoot/login.png" width="160">
  <img src="screenshoot/home.png" width="160">
  <img src="screenshoot/search_cuti.png" width="160">
  <img src="screenshoot/saldo_cuti.png" width="160">
  <img src="screenshoot/profil.png" width="160">
</p>

### 2. Pengajuan Cuti

Pegawai mengisi form pengajuan cuti dalam beberapa tahap, mulai dari memilih jenis cuti dan tanggal, melengkapi data pendukung, sampai mengirim pengajuan.

<p>
  <img src="screenshoot/pengajuan_cuti1.png" width="160">
  <img src="screenshoot/pengajuan_cuti2.png" width="160">
  <img src="screenshoot/pengauan_cuti3.png" width="160">
  <img src="screenshoot/pengajuan_cuti4.png" width="160">
  <img src="screenshoot/pengjuan_cuti5.png" width="160">
</p>

### 3. Persetujuan Berjenjang

Pengajuan diproses bertahap oleh beberapa peran, yaitu up, atasan langsung dan pejabat berwenang. Setiap peran memiliki tampilan untuk menyetujui atau menolak pengajuan.

<p>
  <img src="screenshoot/confirm_atasan1.png" width="160">
  <img src="screenshoot/confirm_atasan2.png" width="160">
  <img src="screenshoot/confirm_pejabat1.png" width="160">
  <img src="screenshoot/confirm_pejabat2.png" width="160">
  <img src="screenshoot/confirm_up1.png" width="160">
  <img src="screenshoot/confirm_up2.png" width="160">
  <img src="screenshoot/confirm_up3.png" width="160">
</p>

### 4. Pembatalan Cuti

Pegawai dapat mengajukan pembatalan cuti yang sudah diajukan atau disetujui. Pembatalan juga melalui alur persetujuan dan ditutup dengan halaman konfirmasi.

<p>
  <img src="screenshoot/pengajuan_pembatalan1.png" width="160">
  <img src="screenshoot/pengajuan_pembatalan2.png" width="160">
  <img src="screenshoot/Pengajuan_pembatalan3.png" width="160">
  <img src="screenshoot/pengajuan_pembatalan4.png" width="160">
  <img src="screenshoot/batalkan_konfirmasi.png" width="160">
</p>

### 5. Riwayat

Seluruh pengajuan cuti dan proses persetujuannya tercatat di halaman riwayat, sehingga status setiap pengajuan dapat dipantau.

<p>
  <img src="screenshoot/history_cuti.png" width="160">
  <img src="screenshoot/riwayat_persetujuan.png" width="160">
</p>

## Teknologi

| Kategori | Teknologi |
|---|---|
| Framework | Flutter |
| Bahasa | Dart |
| State management | Provider |
| Penyimpanan aman | flutter_secure_storage |
| Backend | REST API (Laravel), dikerjakan oleh tim backend |

## Struktur Proyek

```
lib/
├── core/        # Konstanta API dan warna aplikasi
├── providers/   # State management (Provider)
├── screens/     # Halaman-halaman aplikasi
├── services/    # Komunikasi dengan API
└── widgets/     # Komponen UI yang dipakai ulang
```

## Cara Menjalankan

Prasyarat: [Flutter SDK](https://docs.flutter.dev/get-started/install) sudah terpasang.

```bash
git clone https://github.com/ronbob22/simpeg-mobile.git
cd simpeg-mobile
flutter pub get
flutter run
```

> **Catatan:** Aplikasi ini terhubung ke backend milik instansi yang tidak dibuka untuk umum, sehingga fitur yang membutuhkan data dari server tidak dapat dijalankan secara penuh oleh pihak luar. Silakan lihat bagian **Tampilan Aplikasi** untuk gambaran fungsinya.

## Peran Saya

Saya mengerjakan sisi **frontend mobile**: desain antarmuka, integrasi REST API, manajemen state dengan Provider, dan alur persetujuan multi-role. Backend dikerjakan oleh tim lain (senior saya).

## Kontak

Ronald Yakop Simorangkir
- GitHub: [@ronbob22](https://github.com/ronbob22)
- Email: simorangkir.jakop@gmail.com