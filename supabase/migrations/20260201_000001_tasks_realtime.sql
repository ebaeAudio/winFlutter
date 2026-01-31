-- Enable Supabase Realtime on the tasks table.
-- This allows clients to subscribe to INSERT/UPDATE/DELETE events
-- for cross-device task synchronization.
--
-- When a task is added/edited/deleted on one device, other devices
-- receive instant updates via Supabase Realtime channels.

-- Add tasks table to the realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE tasks;

-- Note: Row-level security (RLS) is already enabled on tasks.
-- Realtime subscriptions will only receive events for rows the user owns
-- because of the existing RLS policy filtering by user_id.
