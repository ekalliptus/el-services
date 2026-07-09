# Runbook Deploy — Perbaikan Keamanan Pembayaran

Langkah manual yang WAJIB dilakukan agar perbaikan berlaku di produksi.
Kode client & backend sudah siap; item di bawah butuh akses dashboard/CLI.

## 1. Rotasi kredensial yang sudah bocor (URGENT)
Secret key Xendit lama sudah pernah dibundel di APK → anggap **bocor**.
1. Dashboard Xendit → Settings → API Keys → **revoke** key lama.
2. Buat **Secret API Key** baru.
3. Jangan taruh di aplikasi/.env client. Hanya sebagai secret Edge Function (langkah 3).

## 2. Terapkan migrasi database (RLS + trigger)
```bash
supabase link --project-ref dovyanobuzawvgpwvzgn
supabase db push
```
Atau tempel `supabase/migrations/20260709000000_lock_payment_and_admin.sql`
di SQL Editor. Ini mengunci penulisan status PAID/PROCESSED dari client.
> Bagian 2 (lockdown admins/IDOR) sengaja dikomentari — aktifkan hanya
> setelah login admin dipindah ke Edge Function (lihat catatan di file).

## 3. Set secret Edge Function
```bash
supabase secrets set \
  XENDIT_SECRET_KEY="<key BARU dari langkah 1>" \
  XENDIT_CALLBACK_TOKEN="<verification token, langkah 5>" \
  FIREBASE_PROJECT_ID="<firebase project id>" \
  SUPABASE_JWT_SECRET="<Project Settings -> API -> JWT Secret>"
```
`SUPABASE_URL` & `SUPABASE_SERVICE_ROLE_KEY` tersedia otomatis di runtime.
`SUPABASE_JWT_SECRET` dipakai firebase-bridge untuk menerbitkan sesi user.

## 4. Deploy Edge Functions
```bash
supabase functions deploy create-invoice
supabase functions deploy xendit-webhook --no-verify-jwt
supabase functions deploy firebase-bridge --no-verify-jwt
```

## 5. Daftarkan webhook di Xendit
- Dashboard Xendit → Settings → Webhooks → Invoices.
- Callback URL:
  `https://dovyanobuzawvgpwvzgn.functions.supabase.co/xendit-webhook`
- Salin **Verification Token** → pakai sebagai `XENDIT_CALLBACK_TOKEN` (langkah 3).

## 6. Verifikasi alur
1. Buat service, admin set biaya.
2. User bayar → invoice muncul dari Edge Function (bukan dari secret client).
3. Selesai bayar → webhook Xendit → `services.status = PROCESSED`.
4. Coba manual set status via anon key (mis. REST) → **ditolak** oleh trigger.

## Sisa (butuh pekerjaan backend lanjutan, di luar patch ini)
- **H-3 enkripsi at-rest** password/PIN/pola perangkat: enkripsi via KMS di
  server sebelum disimpan (UI admin sudah di-mask + tap-to-reveal).
- **Bootstrap super_admin pertama**: setelah RLS bagian 2, penambahan admin
  butuh super_admin yang sudah ada / service_role. Buat super_admin pertama
  lewat SQL Editor (service-role) atau Edge Function bootstrap sekali.

## 7. Aktifkan RLS per-user (H-2 IDOR) — SETELAH langkah 4 & rilis client
Migrasi `20260709010000_rls_per_user.sql` mengunci baca/tulis data ke pemilik
(via firebase-bridge) atau admin. **Prasyarat**: build client dengan
`SupabaseAuthBridge` (commit ini) sudah dirilis, dan firebase-bridge sudah
dideploy (langkah 4). Bila dijalankan sebelum itu, user tanpa sesi bridge akan
ditolak RLS.
```bash
supabase db push   # menerapkan 20260709010000_rls_per_user.sql
```
Verifikasi: user A tidak bisa membaca service milik user B; admin tetap
melihat semua; realtime riwayat tetap jalan.
