-- =====================================================================
-- Migrasi keamanan — BAGIAN 2: RLS per-user (menutup IDOR / H-2)
-- =====================================================================
-- PRASYARAT: Edge Function firebase-bridge sudah dideploy dan client sudah
-- memanggil SupabaseAuthBridge.sync() sehingga user biasa memiliki sesi
-- Supabase dgn claim firebase_uid. Admin login via Supabase Auth biasa
-- (auth.uid() = id baris di tabel admins).
--
-- JANGAN jalankan sebelum bridge aktif di client produksi, atau baca data
-- user akan gagal (RLS menolak request tanpa sesi).
--
-- Idempoten. Jalankan setelah 20260709000000.
-- =====================================================================

-- Firebase uid pemanggil dari klaim JWT (null bila memakai anon key murni).
create or replace function public.firebase_uid()
returns text
language sql
stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true)::json
      -> 'user_metadata' ->> 'firebase_uid', ''),
    nullif(current_setting('request.jwt.claims', true)::json
      -> 'app_metadata' ->> 'firebase_uid', '')
  );
$$;

-- Apakah pemanggil seorang admin (punya baris di tabel admins).
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins a where a.id = auth.uid());
$$;

-- ---------------------------------------------------------------------
-- services: pemilik (via firebase_uid) atau admin
-- ---------------------------------------------------------------------
drop policy if exists services_all on public.services;

drop policy if exists services_select on public.services;
create policy services_select on public.services
  for select using (
    auth.role() = 'service_role'
    or public.is_admin()
    or user_id = public.firebase_uid()
  );

drop policy if exists services_insert on public.services;
create policy services_insert on public.services
  for insert with check (
    auth.role() = 'service_role'
    or user_id = public.firebase_uid()
  );

-- UPDATE: pemilik/admin (kolom pembayaran tetap dijaga trigger bagian 1).
drop policy if exists services_update on public.services;
create policy services_update on public.services
  for update using (
    auth.role() = 'service_role'
    or public.is_admin()
    or user_id = public.firebase_uid()
  ) with check (
    auth.role() = 'service_role'
    or public.is_admin()
    or user_id = public.firebase_uid()
  );

drop policy if exists services_delete on public.services;
create policy services_delete on public.services
  for delete using (
    auth.role() = 'service_role' or public.is_admin()
  );

-- ---------------------------------------------------------------------
-- additional_costs: mengikuti kepemilikan service induk
-- ---------------------------------------------------------------------
drop policy if exists addcost_all on public.additional_costs;

drop policy if exists addcost_select on public.additional_costs;
create policy addcost_select on public.additional_costs
  for select using (
    auth.role() = 'service_role'
    or public.is_admin()
    or exists (
      select 1 from public.services s
      where s.id = additional_costs.service_id
        and s.user_id = public.firebase_uid()
    )
  );

drop policy if exists addcost_insert on public.additional_costs;
create policy addcost_insert on public.additional_costs
  for insert with check (
    auth.role() = 'service_role' or public.is_admin()
  );

drop policy if exists addcost_update on public.additional_costs;
create policy addcost_update on public.additional_costs
  for update using (
    auth.role() = 'service_role'
    or public.is_admin()
    or exists (
      select 1 from public.services s
      where s.id = additional_costs.service_id
        and s.user_id = public.firebase_uid()
    )
  ) with check (true);

-- ---------------------------------------------------------------------
-- users: pemilik baris (firebase_uid) atau admin
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'users'
               and column_name = 'firebase_uid') then
    execute 'alter table public.users enable row level security';

    execute 'drop policy if exists users_select on public.users';
    execute $p$create policy users_select on public.users
      for select using (
        auth.role() = 'service_role'
        or public.is_admin()
        or firebase_uid = public.firebase_uid()
      )$p$;

    execute 'drop policy if exists users_upsert on public.users';
    execute $p$create policy users_upsert on public.users
      for all using (
        auth.role() = 'service_role'
        or firebase_uid = public.firebase_uid()
      ) with check (
        auth.role() = 'service_role'
        or firebase_uid = public.firebase_uid()
      )$p$;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- admins: hanya admin terautentikasi yang boleh membaca; tulis service_role
-- ---------------------------------------------------------------------
alter table public.admins enable row level security;

drop policy if exists admins_select on public.admins;
-- Login admin membaca barisnya sendiri (id = auth.uid()) SETELAH auth,
-- serta super_admin boleh melihat semua.
create policy admins_select on public.admins
  for select using (
    auth.role() = 'service_role'
    or id = auth.uid()
    or exists (select 1 from public.admins me
               where me.id = auth.uid() and me.role = 'super_admin')
  );

drop policy if exists admins_write on public.admins;
-- Penambahan/penghapusan admin & eskalasi ke super_admin hanya service_role
-- (mis. lewat Edge Function bootstrap) atau super_admin yang sudah ada.
create policy admins_write on public.admins
  for all using (
    auth.role() = 'service_role'
    or exists (select 1 from public.admins me
               where me.id = auth.uid() and me.role = 'super_admin')
  ) with check (
    auth.role() = 'service_role'
    or exists (select 1 from public.admins me
               where me.id = auth.uid() and me.role = 'super_admin')
  );
