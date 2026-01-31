-- Migration: Trigger remote focus push on command insert (v1)
--
-- Purpose:
-- - When a `remote_focus_commands` row is inserted, enqueue an async HTTP call
--   (pg_net) to the `remote_focus_push` Edge Function to deliver a silent APNs push.
--
-- Notes:
-- - We fetch required secrets from Supabase Vault (vault.decrypted_secrets).
--   You'll need to create these vault secrets in your Supabase project:
--   - SUPABASE_URL
--   - SUPABASE_SERVICE_ROLE_KEY
--
-- Apply with Supabase CLI:
--   supabase db push

create extension if not exists pg_net;
create extension if not exists supabase_vault;

create or replace function public.notify_remote_focus_command()
returns trigger
language plpgsql
security definer
as $$
declare
  supabase_url text;
  service_role_key text;
  endpoint text;
begin
  -- Only push for pending commands targeting iOS (or unspecified target).
  if new.status <> 'pending' then
    return new;
  end if;
  if new.target_platform is not null and lower(new.target_platform) <> 'ios' then
    return new;
  end if;

  select secret into supabase_url
  from vault.decrypted_secrets
  where name = 'SUPABASE_URL'
  limit 1;

  select secret into service_role_key
  from vault.decrypted_secrets
  where name = 'SUPABASE_SERVICE_ROLE_KEY'
  limit 1;

  if supabase_url is null or service_role_key is null then
    -- Don't block inserts if vault isn't configured.
    return new;
  end if;

  endpoint := supabase_url || '/functions/v1/remote_focus_push';

  -- Enqueue async request; it will execute after transaction commit.
  perform net.http_post(
    url := endpoint,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_role_key
    ),
    body := jsonb_build_object(
      'user_id', new.user_id,
      'command_id', new.id
    )
  );

  return new;
exception when others then
  -- Never block app behavior on webhook issues.
  return new;
end;
$$;

drop trigger if exists remote_focus_commands_push_after_insert on public.remote_focus_commands;
create trigger remote_focus_commands_push_after_insert
after insert on public.remote_focus_commands
for each row execute function public.notify_remote_focus_command();

