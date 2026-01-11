-- Migration: Task details (v1) — add `tasks.details`
--
-- Apply with Supabase CLI:
--   supabase db push

-- Ensure updated_at can be maintained automatically on updates.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
begin
  if to_regclass('public.tasks') is null then
    raise notice 'Skipping task details migration: public.tasks does not exist';
    return;
  end if;

  execute 'alter table public.tasks add column if not exists details text';

  if not exists (
    select 1
    from pg_constraint
    where conname = 'tasks_details_length'
      and conrelid = 'public.tasks'::regclass
  ) then
    execute 'alter table public.tasks add constraint tasks_details_length check (details is null or char_length(details) <= 2000)';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'tasks'
      and column_name = 'updated_at'
  ) then
    execute 'drop trigger if exists set_updated_at_tasks on public.tasks';
    execute 'create trigger set_updated_at_tasks before update on public.tasks for each row execute function public.set_updated_at()';
  else
    raise notice 'Skipping updated_at trigger: public.tasks.updated_at does not exist';
  end if;
end
$$;

