-- Add an explicit "in progress" state for tasks.
-- Kept as a separate boolean for minimal disruption and easy back-compat.

alter table public.tasks
add column if not exists in_progress boolean not null default false;

