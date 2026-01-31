-- Add an optional goal/deadline date to tasks.
-- Stored separately from `tasks.date` (the day the task is scheduled/shown on).

do $$
begin
  if to_regclass('public.tasks') is null then
    raise notice 'Skipping task goal date migration: public.tasks does not exist';
    return;
  end if;

  execute 'alter table public.tasks add column if not exists goal_date date';
end
$$;

