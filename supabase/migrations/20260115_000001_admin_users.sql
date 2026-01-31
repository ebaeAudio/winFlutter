-- Migration: Admin users (v1) — secure admin access control
--
-- Apply with Supabase CLI:
--   supabase db push
--
-- To grant admin access to a user, insert their user_id into this table.
-- Example:
--   insert into public.admin_users (user_id) 
--   select id from auth.users where email = 'admin@example.com';

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id)
);

create index if not exists admin_users_created_at_idx on public.admin_users (created_at);

alter table public.admin_users enable row level security;

-- Only admins can read the admin_users table (to check if someone is an admin).
-- Service role can also access for initial setup.
drop policy if exists "admin_users_select_admin" on public.admin_users;
create policy "admin_users_select_admin"
on public.admin_users
for select
using (
  exists (
    select 1
    from public.admin_users
    where user_id = auth.uid()
  )
);

-- Helper function to check if a user is an admin.
-- This can be used in RLS policies for other tables.
-- Marked as SECURITY DEFINER so it can bypass RLS to check admin status.
-- Two overloads: one that takes a user_id, and one that uses the current user's id.
-- Drop first so we can replace any existing version that had different parameter defaults.
-- CASCADE drops dependent RLS policies (e.g. from admin_user_management); they are recreated in the next migration.
drop function if exists public.is_admin(uuid) cascade;
drop function if exists public.is_admin() cascade;
create or replace function public.is_admin(user_id_param uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.admin_users
    where admin_users.user_id = user_id_param
  );
$$;

-- Overload that uses the current user's id (for use in RLS policies)
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.admin_users
    where admin_users.user_id = auth.uid()
  );
$$;

-- Grant execute permission to authenticated users so they can check their own admin status.
grant execute on function public.is_admin(uuid) to authenticated;
grant execute on function public.is_admin() to authenticated;

-- Note: Admin access policy for user_feedback table should be created separately
-- after both this migration and the user_feedback migration (20260112_000001_user_feedback.sql) 
-- have been applied. See migration 20260116_000001_admin_user_management.sql or create it manually:
--
-- drop policy if exists "user_feedback_select_admin" on public.user_feedback;
-- create policy "user_feedback_select_admin"
--   on public.user_feedback
--   for select
--   using (public.is_admin());
