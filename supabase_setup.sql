-- ============================================================
--  RCC FDD Console — Supabase schema
--  Run this ONCE in Supabase → SQL Editor → New query → Run
--  Safe to re-run: everything is idempotent.
-- ============================================================

-- 1. The live status table: one row per (FDD ref × building).
create table if not exists public.fdd_status (
  ref        text not null,
  building   text not null,
  status     text,
  updated_at timestamptz not null default now(),
  updated_by text,
  primary key (ref, building)
);

-- Stamp who/when on every write.
create or replace function public.touch_fdd_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.updated_at := now();
  new.updated_by := coalesce(auth.jwt() ->> 'email', 'unknown');
  return new;
end $$;

drop trigger if exists trg_touch_fdd_status on public.fdd_status;
create trigger trg_touch_fdd_status
  before insert or update on public.fdd_status
  for each row execute function public.touch_fdd_status();

-- 2. Row Level Security — this is what actually protects the data.
--    Anyone with the link can READ. Only a signed-in user can WRITE.
alter table public.fdd_status enable row level security;

drop policy if exists "public read"          on public.fdd_status;
drop policy if exists "authenticated write"  on public.fdd_status;
drop policy if exists "authenticated update" on public.fdd_status;

create policy "public read"
  on public.fdd_status for select
  to anon, authenticated
  using (true);

create policy "authenticated write"
  on public.fdd_status for insert
  to authenticated
  with check (true);

create policy "authenticated update"
  on public.fdd_status for update
  to authenticated
  using (true) with check (true);

-- 3. Audit trail — every status change, who and when.
create table if not exists public.fdd_status_log (
  id         bigserial primary key,
  ref        text not null,
  building   text not null,
  old_status text,
  new_status text,
  changed_at timestamptz not null default now(),
  changed_by text
);

create or replace function public.log_fdd_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  prev text := null;
begin
  if (tg_op = 'UPDATE') then
    prev := old.status;
  end if;

  insert into public.fdd_status_log(ref, building, old_status, new_status, changed_by)
  values (new.ref, new.building, prev, new.status,
          coalesce(auth.jwt() ->> 'email', 'unknown'));

  return new;
end $$;

-- NOTE: TG_OP is NOT allowed in a trigger WHEN clause — only OLD/NEW are.
-- So we use two triggers: one for INSERT, one for UPDATE.
drop trigger if exists trg_log_fdd_status     on public.fdd_status;  -- old broken one, if present
drop trigger if exists trg_log_fdd_status_ins on public.fdd_status;
drop trigger if exists trg_log_fdd_status_upd on public.fdd_status;

create trigger trg_log_fdd_status_ins
  after insert on public.fdd_status
  for each row
  execute function public.log_fdd_status();

create trigger trg_log_fdd_status_upd
  after update on public.fdd_status
  for each row
  when (old.status is distinct from new.status)
  execute function public.log_fdd_status();

alter table public.fdd_status_log enable row level security;
drop policy if exists "public read log" on public.fdd_status_log;
create policy "public read log"
  on public.fdd_status_log for select
  to anon, authenticated
  using (true);

-- Done.
-- Next: Table Editor → fdd_status → Insert → Import data from CSV
--       and upload seed_fdd_status.csv
