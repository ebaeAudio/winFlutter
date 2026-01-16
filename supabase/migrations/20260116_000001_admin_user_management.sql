-- Migration: Admin user management — RLS policies and helper function
--
-- Apply with Supabase CLI:
--   supabase db push
--
-- This migration adds:
-- 1. RLS policies for INSERT/DELETE on admin_users (for grant/revoke operations)
-- 2. admin_list_users() function to efficiently query users with admin status

-- Allow admins to insert into admin_users (grant admin access)
drop policy if exists "admin_users_insert_admin" on public.admin_users;
create policy "admin_users_insert_admin"
on public.admin_users
for insert
with check (public.is_admin());

-- Allow admins to delete from admin_users (revoke admin access)
drop policy if exists "admin_users_delete_admin" on public.admin_users;
create policy "admin_users_delete_admin"
on public.admin_users
for delete
using (public.is_admin());

-- Function to get user list with admin status (for admins only)
-- This function uses security definer to bypass RLS on auth.users
-- but still enforces that only admins can call it.
create or replace function public.admin_list_users()
returns table (
  user_id uuid,
  email text,
  created_at timestamptz,
  is_admin boolean,
  admin_granted_at timestamptz,
  admin_granted_by uuid
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  -- Only allow admins to call this function
  if not public.is_admin() then
    raise exception 'Access denied. Admin privileges required.';
  end if;

  return query
  select 
    u.id as user_id,
    u.email::text,
    u.created_at,
    exists(select 1 from admin_users au where au.user_id = u.id) as is_admin,
    au.created_at as admin_granted_at,
    au.created_by as admin_granted_by
  from auth.users u
  left join admin_users au on au.user_id = u.id
  order by u.created_at desc;
end;
$$;

-- Grant execute permission to authenticated users
-- The function itself checks admin status, so this is safe
grant execute on function public.admin_list_users() to authenticated;

-- Grant admins read access to user_feedback for triage (if the table exists)
-- This policy allows admins to view all user feedback for triage purposes
do $$
begin
  if to_regclass('public.user_feedback') is not null then
    execute 'drop policy if exists "user_feedback_select_admin" on public.user_feedback';
    execute 'create policy "user_feedback_select_admin" on public.user_feedback for select using (public.is_admin())';
  end if;
end
$$;
