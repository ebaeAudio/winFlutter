-- Migration: Focus active session sync (v1)
--
-- Purpose:
-- - Allow the app to sync the currently-active Dumb Phone Mode session across
--   devices (e.g., iPhone runs the session; macOS displays the same countdown).
-- - We store only the "active session" record (one row per user). When the
--   session ends, the row is deleted.
--
-- Apply with Supabase CLI:
--   supabase db push

create table if not exists public.focus_active_sessions (
  user_id uuid primary key references auth.users (id) on delete cascade,

  -- Mirrors the app's FocusSession model (mostly)
  session_id text not null,
  policy_id text not null,
  started_at timestamptz not null,
  planned_end_at timestamptz not null,
  emergency_unlocks_used integer not null default 0 check (emergency_unlocks_used >= 0),

  -- Helpful metadata for UI ("started on iPhone") and debugging.
  source_platform text,
  updated_at timestamptz not null default now()
);

create index if not exists focus_active_sessions_user_id_idx
  on public.focus_active_sessions (user_id);

alter table public.focus_active_sessions enable row level security;

drop policy if exists "focus_active_sessions_select_own" on public.focus_active_sessions;
create policy "focus_active_sessions_select_own"
on public.focus_active_sessions
for select
using (auth.uid() = user_id);

drop policy if exists "focus_active_sessions_insert_own" on public.focus_active_sessions;
create policy "focus_active_sessions_insert_own"
on public.focus_active_sessions
for insert
with check (auth.uid() = user_id);

drop policy if exists "focus_active_sessions_update_own" on public.focus_active_sessions;
create policy "focus_active_sessions_update_own"
on public.focus_active_sessions
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "focus_active_sessions_delete_own" on public.focus_active_sessions;
create policy "focus_active_sessions_delete_own"
on public.focus_active_sessions
for delete
using (auth.uid() = user_id);

