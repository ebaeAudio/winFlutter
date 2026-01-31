-- Migration: User feedback (v1) — collect bug reports & improvement ideas
--
-- Apply with Supabase CLI:
--   supabase db push

create table if not exists public.user_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('bug', 'improvement')),
  description text not null,
  details text,
  entry_point text,
  context jsonb,
  created_at timestamptz not null default now()
);

create index if not exists user_feedback_user_id_idx on public.user_feedback (user_id);
create index if not exists user_feedback_kind_created_at_idx on public.user_feedback (kind, created_at desc);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_feedback_description_length'
      and conrelid = 'public.user_feedback'::regclass
  ) then
    execute 'alter table public.user_feedback add constraint user_feedback_description_length check (char_length(description) <= 280)';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_feedback_details_length'
      and conrelid = 'public.user_feedback'::regclass
  ) then
    execute 'alter table public.user_feedback add constraint user_feedback_details_length check (details is null or char_length(details) <= 2000)';
  end if;
end
$$;

alter table public.user_feedback enable row level security;

-- Insert-only from the app. (Dev team can triage from Supabase dashboard / admin tooling.)
drop policy if exists "user_feedback_insert_own" on public.user_feedback;
create policy "user_feedback_insert_own"
on public.user_feedback
for insert
with check (auth.uid() = user_id);

