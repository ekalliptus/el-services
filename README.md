# Service HP Online (ANRServices)

Aplikasi mobile layanan servis perangkat (service HP) yang menghubungkan pelanggan dengan teknisi: pemesanan servis, keluhan, testimoni, dan panel admin. Dibangun dengan Flutter untuk Android dan iOS.

## Fitur

- Autentikasi: Firebase Auth dengan email/password dan Google Sign-In.
- Panel pengguna: pemesanan servis/maintenance, pengajuan komplain, testimoni, profil.
- Panel admin dan super admin: kelola order, komplain, testimoni, dan versi aplikasi.
- Peta dan lokasi: `flutter_map` + `geolocator` + `geocoding`.
- Pembaruan dalam aplikasi (in-app update): APK diunduh dari Supabase Storage, informasi versi dari tabel Supabase.

## Tech Stack

- Flutter (Dart), state management `flutter_bloc`
- Firebase (Auth, Core), Supabase (database, storage, update APK)
- `flutter_map`, `geolocator`, `flutter_screenutil`, `webview_flutter`

## Menjalankan

```bash
cp .env.example .env   # isi kredensial Supabase/Firebase
flutter pub get
flutter run
```

Build APK: `flutter build apk --release`.

## Sistem Update Dalam Aplikasi

# Service HP Online

## In-App Update System

Aplikasi ini menggunakan sistem pembaruan dalam aplikasi (in-app update) yang dikelola melalui Supabase, memungkinkan pengguna menerima pembaruan aplikasi tanpa perlu mengunjungi Play Store.

### Cara Kerja

1. **Penyimpanan Data Versi**: Informasi versi disimpan dalam tabel `versions` di Supabase.
2. **Penyimpanan APK**: File APK disimpan di Supabase Storage bucket `updates`.
3. **Pengecekan Versi**: Aplikasi secara periodik memeriksa versi terbaru di Supabase dan membandingkannya dengan versi yang terinstal.
4. **Unduh & Instalasi**: Jika versi baru tersedia, pengguna dapat mengunduh dan menginstal APK secara langsung dari aplikasi.

### Pengelolaan Versi

Admin dapat mengelola versi aplikasi melalui dashboard admin:
1. Masuk ke halaman admin
2. Klik ikon "Kelola Versi Aplikasi" di toolbar
3. Unggah APK baru dan isi informasi versi (versi, catatan rilis, dll.)

### Versioning

Aplikasi menggunakan skema versioning berikut:
- **versionCode**: Integer yang selalu meningkat (digunakan untuk membandingkan versi)
- **versionName**: Format "MAJOR.MINOR.PATCH" (Semantic Versioning)

#### Panduan Pembaruan Versi

Untuk merilis pembaruan baru:
1. Naikkan `versionCode` di `android/app/build.gradle` 
2. Perbarui `versionName` sesuai dengan jenis perubahan
3. Build APK
4. Unggah APK melalui dashboard admin

#### Tabel Database

Schema tabel `versions` di Supabase:
```sql
CREATE TABLE versions (
    id SERIAL PRIMARY KEY,
    platform TEXT NOT NULL,
    latest_version_code INTEGER NOT NULL,
    latest_version_name TEXT NOT NULL,
    apk_download_url TEXT NOT NULL,
    release_notes TEXT,
    is_mandatory BOOLEAN DEFAULT FALSE,
    file_hash TEXT,
    file_size INTEGER,
    published_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Informasi Teknis Tambahan

- APK yang diunggah harus diinstal secara manual oleh pengguna
- Pastikan APK ditandatangani dengan kunci yang sama untuk memungkinkan instalasi sebagai pembaruan

