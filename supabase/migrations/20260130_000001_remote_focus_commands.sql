-- Migration: Remote focus commands + user devices (v1)
--
-- Purpose:
-- - Allow one device (e.g., macOS) to request starting/stopping Focus on another
--   device (e.g., iPhone) using a command queue.
-- - Store push notification tokens per user device so an Edge Function can
--   deliver a silent push to wake the target device.
--
-- Apply with Supabase CLI:
--   supabase db push

create table if not exists public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  -- Metadata
  platform text not null, -- e.g. "ios", "macos"
  device_name text,

  -- Push delivery
  push_provider text not null default 'apns', -- "apns" (future: "fcm")
  push_token text not null,

  -- Auditing
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists user_devices_user_token_unique
  on public.user_devices (user_id, push_provider, push_token);

create index if not exists user_devices_user_id_idx
  on public.user_devices (user_id);

create index if not exists user_devices_platform_idx
  on public.user_devices (platform);

alter table public.user_devices enable row level security;

drop policy if exists "user_devices_select_own" on public.user_devices;
create policy "user_devices_select_own"
on public.user_devices
for select
using (auth.uid() = user_id);

drop policy if exists "user_devices_insert_own" on public.user_devices;
create policy "user_devices_insert_own"
on public.user_devices
for insert
with check (auth.uid() = user_id);

drop policy if exists "user_devices_update_own" on public.user_devices;
create policy "user_devices_update_own"
on public.user_devices
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "user_devices_delete_own" on public.user_devices;
create policy "user_devices_delete_own"
on public.user_devices
for delete
using (auth.uid() = user_id);

-- Remote focus commands.
create table if not exists public.remote_focus_commands (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  -- Command payload
  command text not null check (command in ('start', 'stop')),
  policy_id text, -- Optional: referenced by app logic (policies are currently local-only)
  duration_minutes integer check (duration_minutes is null or duration_minutes > 0),

  -- Routing + state
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'completed', 'failed', 'expired')),
  source_platform text not null, -- e.g. "macos"
  target_platform text, -- e.g. "ios"

  -- Timing
  created_at timestamptz not null default now(),
  processed_at timestamptz,

  -- Error detail if failed
  error_message text
);

create index if not exists remote_focus_commands_user_id_idx
  on public.remote_focus_commands (user_id);

create index if not exists remote_focus_commands_status_created_idx
  on public.remote_focus_commands (user_id, status, created_at desc);

alter table public.remote_focus_commands enable row level security;

drop policy if exists "remote_focus_commands_select_own" on public.remote_focus_commands;
create policy "remote_focus_commands_select_own"
on public.remote_focus_commands
for select
using (auth.uid() = user_id);

drop policy if exists "remote_focus_commands_insert_own" on public.remote_focus_commands;
create policy "remote_focus_commands_insert_own"
on public.remote_focus_commands
for insert
with check (auth.uid() = user_id);

drop policy if exists "remote_focus_commands_update_own" on public.remote_focus_commands;
create policy "remote_focus_commands_update_own"
on public.remote_focus_commands
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "remote_focus_commands_delete_own" on public.remote_focus_commands;
create policy "remote_focus_commands_delete_own"
on public.remote_focus_commands
for delete
using (auth.uid() = user_id);

