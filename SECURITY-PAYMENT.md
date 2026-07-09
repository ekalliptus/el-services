# Keamanan Pembayaran & Data Sensitif — Rencana Perbaikan

> Dokumen ini merangkum temuan keamanan **kritikal** dari audit dan rencana perbaikan
> sisi server. Perbaikan sisi client sudah sebagian dikerjakan (lihat bagian akhir),
> tetapi **akar masalah pembayaran hanya bisa ditutup dengan backend** — jangan
> mematikan alur client yang sekarang berjalan sebelum backend siap, agar transaksi
> tidak putus di produksi.

---

## Ringkasan Eksekutif

Arsitektur pembayaran saat ini **mempercayai client sepenuhnya**. Tiga masalah saling
menguatkan:

1. **Secret key Xendit dibundel di aplikasi** dan dipakai langsung dari HP.
2. **Status pembayaran ditulis oleh client** (anon key publik), tanpa verifikasi server.
3. **Tidak ada webhook** gateway yang mengonfirmasi transaksi.

Akibatnya: order bisa ditandai **LUNAS tanpa membayar**, dan **kredensial Xendit bisa
dicuri** dari APK. Keduanya berdampak finansial langsung.

Prinsip target: **client tidak pernah menentukan atau menulis status pembayaran.**
Kebenaran status hanya berasal dari **webhook gateway → backend (service-role) → DB**,
dan client hanya **membaca/berlangganan** status tersebut.

---

## Temuan Kritikal & High (terkait pembayaran/identitas)

| # | Lokasi | Masalah | Severity |
|---|--------|---------|:---:|
| C1 | `lib/core/services/payment_service.dart:11,181-202,240-249` | Secret key Xendit dipakai untuk Basic-Auth & memanggil `api.xendit.co` langsung dari client. `.env` di-bundel sebagai asset (`pubspec.yaml`), mudah diekstrak dari APK. | 🔴 Critical |
| C2 | `lib/features/user/pages/payment_webview_page.dart` | Status ditentukan dari **URL redirect** yang bisa dipalsukan (WebView `unrestricted`). | 🔴 Critical |
| H1 | `payment_service.dart:259` | `getPaymentStatus` menulis `services.status` dari client dengan anon key; tak ada webhook. | 🟠 High |
| H2 | `lib/core/services/service_api.dart:62` | `userId` dikirim sebagai **parameter** tanpa token auth → IDOR (baca data user lain). | 🟠 High |
| M1 | `lib/features/admin/dialogs/update_cost_dialog.dart:124` | Client langsung menulis `service_cost` & `status`. | 🟡 Medium |
| M2 | `lib/features/complaint/pages/complaint_page.dart:428` | Client menulis `services.status` tanpa cek kepemilikan server-side. | 🟡 Medium |
| M3 | `super_admin_setup_page.dart:74` | Registrasi super_admin dikontrol client. | 🟡 Medium |

> Data sensitif tambahan: **password/PIN/pola kunci perangkat** disimpan **plaintext** di
> tabel `services` (`home_page_three.dart`, `confirmation_page.dart`, `service_model.dart`),
> dan dibaca-balik verbatim di kartu admin. Lihat bagian "Data Sensitif" di bawah.

---

## Arsitektur Target

```
                     (rahasia hanya di server)
  App (client)  ──►  Backend api.servicehponline.com  ──►  Xendit API
     │  create invoice (Bearer Firebase ID token)          (secret key)
     │
     │  ◄── invoice_url saja (tanpa secret)
     │
  Xendit  ──► Webhook (X-Callback-Token / signature) ──► Backend ──► Supabase (service-role)
                                                                    update services.status
     │
  App  ◄── realtime/poll status dari Supabase (RLS: read-only untuk kolom status)
```

### Aturan emas
- **Secret key TIDAK PERNAH** ada di client. Rotasi key yang sekarang ter-bundle **segera**.
- Client **hanya membaca** status; **tidak menulis** `status`, `service_cost`,
  `xendit_invoice_id`, `payment_url`.
- Setiap request ke backend membawa **Firebase ID token** (`Authorization: Bearer <token>`);
  backend memverifikasi token & memastikan **kepemilikan** resource sebelum bertindak.

---

## Langkah Implementasi Backend

### 1. Endpoint proxy pembuatan invoice
`POST /payments/invoices` (auth: Firebase ID token)
- Verifikasi ID token (Firebase Admin SDK) → dapatkan `uid`.
- Pastikan `service_id` pada body milik `uid` (query Supabase pakai service-role).
- Panggil Xendit `POST /v2/invoices` dengan **secret key di server**.
- Simpan `xendit_invoice_id`, `payment_url` ke `services` via service-role.
- Balas ke client **hanya** `{ invoice_url }`.

### 2. Webhook konfirmasi pembayaran
`POST /payments/webhook/xendit`
- Verifikasi header `x-callback-token` (Xendit) — tolak bila tidak cocok.
- Ambil `external_id`/`id`, petakan ke `service_id`.
- Update `services.status` (mis. `PROCESSED`) & `additional_costs.status` (`PAID`) via
  **service-role**, idempoten (cek status sekarang agar tidak dobel).
- Catat audit log (waktu, invoice id, status).

### 3. Endpoint status (opsional bila tak pakai realtime)
`GET /payments/status?service_id=...` (auth) → baca status dari DB (bukan dari Xendit
oleh client).

### 4. Ganti pemakaian di client
- `payment_service.dart`: `createPayment`/`getPaymentStatus` → panggil backend
  (`$_baseUrl/...`) dengan Bearer token. Hapus semua pemakaian `_xenditKey` dari client.
- `payment_webview_page.dart`: hilangkan penulisan status dari redirect; cukup tutup
  WebView lalu **poll/subscribe** status dari Supabase (yang hanya di-update webhook).
  > Perbaikan sementara sudah diterapkan: gagal ≠ PAID, dan sukses tak diklaim bila
  > penulisan DB gagal. Tapi ini **bukan** pengganti webhook.
- `service_api.dart`: kirim Bearer token; **jangan** kirim `userId` sebagai parameter
  yang dipercaya — identitas diambil dari token di server.

---

## Row Level Security (Supabase)

Terapkan RLS agar client (anon/authenticated) **tidak bisa** menulis kolom sensitif.
Contoh kebijakan (sesuaikan dengan skema & mekanisme identitas Anda — jika memakai
Firebase, verifikasi dilakukan di backend service-role, dan RLS mengunci akses langsung):

```sql
-- Aktifkan RLS
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE additional_costs ENABLE ROW LEVEL SECURITY;

-- Client TIDAK boleh menulis kolom status/biaya/invoice secara langsung.
-- Semua penulisan status dilakukan backend memakai service-role (bypass RLS).

-- Contoh: izinkan pemilik membaca service miliknya saja.
-- (Ganti owner_uid dgn kolom identitas yang Anda pakai.)
CREATE POLICY services_select_owner ON services
  FOR SELECT USING (owner_uid = auth.uid());

-- Larang UPDATE dari client sepenuhnya (tidak ada policy UPDATE untuk role anon/authenticated).
-- Backend memakai service-role key yang bypass RLS.

-- Kunci kolom testimonial/publik yang perlu dibaca publik secukupnya.
```

> Catatan penting: aplikasi ini memakai **Firebase Auth**, sehingga `auth.uid()` Supabase
> **tidak** otomatis terisi. Selama identitas belum diintegrasikan ke JWT Supabase, jalur
> paling aman adalah: **semua tulis lewat backend service-role**, dan RLS menolak semua
> UPDATE dari anon/authenticated. Verifikasi kepemilikan dilakukan backend via Firebase ID token.

---

## Data Sensitif: Kunci Perangkat & Token

### Kunci perangkat (PIN/pola/password) — plaintext di DB
- **Jangan** simpan rahasia mentah. Bila teknisi butuh membuka perangkat:
  - Enkripsi at-rest (envelope encryption / KMS di server), akses ketat via RLS.
  - **Mask** di semua tampilan client/admin; reveal on-demand dengan audit.
- Sudah/segera di client: masking tampilan + komentar penanda. Enkripsi butuh sisi server.

### Token admin
- ✅ **Sudah diperbaiki**: token admin dipindah dari SharedPreferences plaintext ke
  `flutter_secure_storage` (Keystore/Keychain) via `lib/core/services/secure_store.dart`,
  dengan migrasi otomatis satu kali dari penyimpanan lama.
- ✅ Bug `setSession(access_token)` diperbaiki → memakai **refresh token** (sesuai API Supabase).

---

## Rotasi Kredensial (WAJIB, segera)
1. **Rotate Xendit secret key** — anggap key yang ter-bundle sudah bocor.
2. Setelah backend proxy siap, **cabut** kemampuan key dipakai dari client.
3. Pertimbangkan membatasi scope/permission key Xendit seminimal mungkin.

---

## Perbaikan Client yang Sudah Dikerjakan (branch `fix/security-stability-audit`)
- Token admin → secure storage (+ migrasi), fix `setSession` refresh-token.
- `payment_webview_page`: gagal tidak lagi ditandai PAID; sukses tidak diklaim bila DB gagal; guard `mounted`.
- Startup `main()` tidak lagi hang bila init gagal (menampilkan layar error); `.env` opsional.
- Navigasi pasca-login disatukan (hapus triple-navigation).
- Kebocoran memori (Timer/StreamController/VideoPlayerController/subscription) & crash lifecycle diperbaiki.
- `dispose()` dialog video tidak lagi crash (`LateInitializationError`).

**Belum tertutup tanpa backend:** C1, C2, H1, H2, M1–M3, dan enkripsi kunci perangkat.
Ini memerlukan implementasi backend + RLS sesuai dokumen ini.
