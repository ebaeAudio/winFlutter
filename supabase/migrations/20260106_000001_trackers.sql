-- Migration: Custom Trackers schema (v1)
-- Source: supabase/trackers_schema.sql
--
-- Apply with Supabase CLI:
--   supabase db push

-- Trackers
create table if not exists public.trackers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  items jsonb not null,
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists trackers_user_id_idx on public.trackers (user_id);
create index if not exists trackers_user_id_archived_idx on public.trackers (user_id, archived);

alter table public.trackers enable row level security;

drop policy if exists "trackers_select_own" on public.trackers;
create policy "trackers_select_own"
on public.trackers
for select
using (auth.uid() = user_id);

drop policy if exists "trackers_insert_own" on public.trackers;
create policy "trackers_insert_own"
on public.trackers
for insert
with check (auth.uid() = user_id);

drop policy if exists "trackers_update_own" on public.trackers;
create policy "trackers_update_own"
on public.trackers
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "trackers_delete_own" on public.trackers;
create policy "trackers_delete_own"
on public.trackers
for delete
using (auth.uid() = user_id);

-- Tracker tallies
create table if not exists public.tracker_tallies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  tracker_id uuid not null references public.trackers (id) on delete cascade,
  item_key text not null,
  date text not null, -- YYYY-MM-DD
  count integer not null default 0 check (count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists tracker_tallies_user_id_date_idx on public.tracker_tallies (user_id, date);
create index if not exists tracker_tallies_tracker_id_date_idx on public.tracker_tallies (tracker_id, date);

create unique index if not exists tracker_tallies_unique
  on public.tracker_tallies (user_id, tracker_id, item_key, date);

alter table public.tracker_tallies enable row level security;

drop policy if exists "tracker_tallies_select_own" on public.tracker_tallies;
create policy "tracker_tallies_select_own"
on public.tracker_tallies
for select
using (auth.uid() = user_id);

drop policy if exists "tracker_tallies_insert_own" on public.tracker_tallies;
create policy "tracker_tallies_insert_own"
on public.tracker_tallies
for insert
with check (auth.uid() = user_id);

drop policy if exists "tracker_tallies_update_own" on public.tracker_tallies;
create policy "tracker_tallies_update_own"
on public.tracker_tallies
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "tracker_tallies_delete_own" on public.tracker_tallies;
create policy "tracker_tallies_delete_own"
on public.tracker_tallies
for delete
using (auth.uid() = user_id);


