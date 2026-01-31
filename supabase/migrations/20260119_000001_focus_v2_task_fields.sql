-- Migration: Focus v2 task fields — starter_step + estimated_minutes
--
-- Apply with Supabase CLI:
--   supabase db push

do $$
begin
  if to_regclass('public.tasks') is null then
    raise notice 'Skipping Focus v2 task fields migration: public.tasks does not exist';
    return;
  end if;

  execute 'alter table public.tasks add column if not exists starter_step text';
  execute 'alter table public.tasks add column if not exists estimated_minutes integer';
end
$$;

