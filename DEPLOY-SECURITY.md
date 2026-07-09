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
  FIREBASE_PROJECT_ID="<firebase project id>"
```
`SUPABASE_URL` & `SUPABASE_SERVICE_ROLE_KEY` tersedia otomatis di runtime.

## 4. Deploy Edge Functions
```bash
supabase functions deploy create-invoice
supabase functions deploy xendit-webhook --no-verify-jwt
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
- **H-2 IDOR** baca riwayat: pindahkan read per-user ke Edge Function bertoken
  Firebase, lalu aktifkan RLS bagian 2.
- **H-3 enkripsi at-rest** password/PIN/pola perangkat: enkripsi via KMS di
  server sebelum disimpan (UI admin sudah di-mask + tap-to-reveal).
- **Login admin**: verifikasi kredensial via Edge Function service-role,
  bukan baca tabel `admins` dari anon.
