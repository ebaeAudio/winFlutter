-- Supabase schema changes required for Task Details (notes/tracking/subtasks)
-- Apply these in the Supabase SQL editor.

-- 1) Add detail fields to `tasks`
alter table public.tasks
  add column if not exists notes text,
  add column if not exists estimate_minutes integer,
  add column if not exists actual_minutes integer,
  add column if not exists next_step text;

-- Focus v2 (MVP): add task fields used by Focus mode
alter table public.tasks
  add column if not exists starter_step text,
  add column if not exists estimated_minutes integer;

-- 2) Create `task_subtasks`
create table if not exists public.task_subtasks (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  title text not null,
  completed boolean not null default false,
  sort_order integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists task_subtasks_task_id_idx on public.task_subtasks(task_id);

-- 3) RLS policies
alter table public.task_subtasks enable row level security;

-- Users can read subtasks for their own tasks
create policy if not exists "task_subtasks_select_own"
on public.task_subtasks
for select
using (
  exists (
    select 1
    from public.tasks t
    where t.id = task_subtasks.task_id
      and t.user_id = auth.uid()
  )
);

-- Users can insert subtasks for their own tasks
create policy if not exists "task_subtasks_insert_own"
on public.task_subtasks
for insert
with check (
  exists (
    select 1
    from public.tasks t
    where t.id = task_subtasks.task_id
      and t.user_id = auth.uid()
  )
);

-- Users can update subtasks for their own tasks
create policy if not exists "task_subtasks_update_own"
on public.task_subtasks
for update
using (
  exists (
    select 1
    from public.tasks t
    where t.id = task_subtasks.task_id
      and t.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.tasks t
    where t.id = task_subtasks.task_id
      and t.user_id = auth.uid()
  )
);

-- Users can delete subtasks for their own tasks
create policy if not exists "task_subtasks_delete_own"
on public.task_subtasks
for delete
using (
  exists (
    select 1
    from public.tasks t
    where t.id = task_subtasks.task_id
      and t.user_id = auth.uid()
  )
);


