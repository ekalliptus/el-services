-- =====================================================================
-- Migrasi keamanan pembayaran — BAGIAN 1 (AMAN DIAKTIFKAN SEKARANG)
-- =====================================================================
-- Model auth aplikasi saat ini: SEMUA client (termasuk panel admin)
-- memakai Supabase ANON key; identitas user dipegang Firebase. Tidak ada
-- service-role client di aplikasi Flutter. auth.uid() = NULL untuk semua
-- request, jadi kepemilikan tidak bisa dicek di RLS.
--
-- Bagian 1 mengunci HANYA status pembayaran: client tidak boleh lagi
-- menandai service PAID/PROCESSED sendiri. Perubahan sah datang dari
-- Edge Function xendit-webhook (service_role). Ini menutup Crit-2 & H-1
-- TANPA memutus fitur admin (admin men-set service_cost & status non-bayar
-- tetap boleh; hanya transisi ke PAID/PROCESSED yang dikunci server).
--
-- Idempoten. Jalankan: supabase db push, atau tempel di SQL editor.
-- =====================================================================

-- Kolom untuk mencocokkan webhook Xendit ke service.
alter table public.services
  add column if not exists xendit_external_id text;

create index if not exists services_xendit_external_id_idx
  on public.services (xendit_external_id);

-- ---------------------------------------------------------------------
-- Trigger: hanya server (service_role) boleh menandai PAID/PROCESSED,
-- dan hanya server boleh mengubah kolom identitas pembayaran Xendit.
-- Admin/user via anon tetap boleh mengubah status ke nilai non-final
-- (mis. PENDING, IN_PROGRESS, DONE) dan set service_cost.
-- ---------------------------------------------------------------------
create or replace function public.enforce_payment_status_server_only()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'service_role' then
    return new;
  end if;

  -- Naik ke status pembayaran final hanya boleh dari server.
  if new.status is distinct from old.status
     and new.status in ('PAID', 'PROCESSED') then
    raise exception 'status pembayaran hanya boleh diubah oleh server (webhook Xendit)';
  end if;

  -- Identitas invoice Xendit hanya boleh diisi/ubah server.
  if new.xendit_invoice_id is distinct from old.xendit_invoice_id
     or new.xendit_external_id is distinct from old.xendit_external_id
     or new.payment_url is distinct from old.payment_url then
    raise exception 'kolom invoice Xendit hanya boleh diubah oleh server';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_payment_status on public.services;
create trigger trg_enforce_payment_status
  before update on public.services
  for each row execute function public.enforce_payment_status_server_only();

-- additional_costs: transisi ke PAID/PROCESSED hanya server.
create or replace function public.enforce_addcost_paid_server_only()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'service_role' then
    return new;
  end if;
  if tg_op = 'UPDATE'
     and new.status is distinct from old.status
     and new.status in ('PAID', 'PROCESSED') then
    raise exception 'status bayar biaya tambahan hanya diubah server';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_addcost_paid on public.additional_costs;
create trigger trg_enforce_addcost_paid
  before update on public.additional_costs
  for each row execute function public.enforce_addcost_paid_server_only();

-- Aktifkan RLS dengan policy permisif (kolom sensitif dijaga trigger).
alter table public.services enable row level security;
drop policy if exists services_all on public.services;
create policy services_all on public.services
  for all using (true) with check (true);

alter table public.additional_costs enable row level security;
drop policy if exists addcost_all on public.additional_costs;
create policy addcost_all on public.additional_costs
  for all using (true) with check (true);


-- =====================================================================
-- BAGIAN 2 (JANGAN AKTIFKAN sampai admin auth pindah ke server)
-- =====================================================================
-- Temuan tambahan (H-2 IDOR baca, registrasi super_admin dari client,
-- baca tabel admins dari anon) HANYA bisa ditutup setelah:
--   1. Login admin diverifikasi via Edge Function bertoken (bukan baca
--      tabel admins langsung dari anon).
--   2. Baca riwayat service per-user dipindah ke Edge Function bertoken
--      Firebase, agar bisa memfilter user_id = pemanggil.
--
-- Jika DIAKTIFKAN sekarang, panel admin & login admin akan PUTUS karena
-- aplikasi belum punya client service-role. Aktifkan HANYA setelah migrasi
-- di atas. Skrip disimpan sebagai komentar sengaja.
--
--   alter table public.admins enable row level security;
--   create policy admins_service_only on public.admins
--     for all using (auth.role() = 'service_role')
--     with check (auth.role() = 'service_role');
--
--   -- Kunci baca services agar tak bisa IDOR dari anon (butuh read via
--   -- Edge Function bertoken lebih dulu):
--   drop policy if exists services_all on public.services;
--   create policy services_rw on public.services
--     for all using (auth.role() = 'service_role')
--     with check (auth.role() = 'service_role');
-- =====================================================================
