-- Migration: Rate limiting primitives for public endpoints (v1)
--
-- Purpose:
-- - Provide a durable, server-side rate limiter for Supabase Edge Functions.
-- - Rate limiting is enforced server-side to align with OWASP API Security guidance
--   (protect availability; throttle brute-force & abuse).
--
-- Design:
-- - Windowed counter keyed by (key, bucket).
-- - An atomic RPC (`public.rate_limit_check`) increments + returns allow/deny with Retry-After.
-- - RLS is enabled with NO policies so clients cannot read/write counters (service role bypasses RLS).
--
-- Apply with Supabase CLI:
--   supabase db push

create table if not exists public.rate_limits (
  key text not null,
  bucket bigint not null,
  count integer not null default 0 check (count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (key, bucket)
);

create index if not exists rate_limits_updated_at_idx on public.rate_limits (updated_at);

alter table public.rate_limits enable row level security;

-- IMPORTANT:
-- Do NOT add policies here. With RLS enabled and no policies, anon/auth users cannot access.
-- Service role can still access for Edge Function enforcement.

create or replace function public.rate_limit_check(
  p_key text,
  p_window_seconds integer,
  p_max_requests integer
)
returns table (
  ok boolean,
  retry_after_seconds integer,
  "limit" integer,
  remaining integer,
  reset_seconds integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_epoch bigint := extract(epoch from v_now);
  v_window integer := greatest(1, least(86400, coalesce(p_window_seconds, 60)));
  v_limit integer := greatest(1, least(10000, coalesce(p_max_requests, 60)));
  v_bucket bigint := floor(v_epoch::numeric / v_window);
  v_reset_in integer := (v_window - (v_epoch % v_window))::int;
  v_count integer;
begin
  if p_key is null or length(trim(p_key)) = 0 then
    ok := false;
    retry_after_seconds := 1;
    "limit" := v_limit;
    remaining := 0;
    reset_seconds := v_reset_in;
    return next;
    return;
  end if;

  insert into public.rate_limits(key, bucket, count, created_at, updated_at)
  values (p_key, v_bucket, 1, v_now, v_now)
  on conflict (key, bucket) do update
    set count = public.rate_limits.count + 1,
        updated_at = v_now
  returning count into v_count;

  if v_count > v_limit then
    ok := false;
    retry_after_seconds := greatest(1, v_reset_in);
    "limit" := v_limit;
    remaining := 0;
    reset_seconds := v_reset_in;
    return next;
    return;
  end if;

  ok := true;
  retry_after_seconds := 0;
  "limit" := v_limit;
  remaining := greatest(0, v_limit - v_count);
  reset_seconds := v_reset_in;
  return next;
end;
$$;

revoke all on function public.rate_limit_check(text, integer, integer) from public;
grant execute on function public.rate_limit_check(text, integer, integer) to service_role;


