-- Add soft delete support for tasks.
-- When deleted_at is set, the task is considered deleted but can be recovered.

alter table public.tasks
add column if not exists deleted_at timestamptz;

-- Create index for efficient filtering of non-deleted tasks.
create index if not exists idx_tasks_deleted_at on public.tasks (deleted_at)
where deleted_at is null;

-- Add comment for documentation.
comment on column public.tasks.deleted_at is 'Soft delete timestamp. If set, task is considered deleted but recoverable.';
