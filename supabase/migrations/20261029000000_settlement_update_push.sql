-- ============================================================================
-- Push notification when a pending payment is CONFIRMED or CANCELLED.
--
-- record_settlement() INSERTs a row → the "notify-new-settlement" Database
-- Webhook sends a push. confirm_settlement() / cancel_settlement() only
-- UPDATE the row, so until now they wrote an in-app notification but sent
-- no push. This trigger calls the send-push-notification Edge Function for
-- those UPDATEs, with the same JSON a Database Webhook sends
-- ({type, table, schema, record, old_record}).
--
-- The in-app notification is still written by the two RPCs
-- (_notify_settlement, unchanged). The Edge Function sends ONLY the push
-- for these events, so nobody gets two in-app notifications.
--
-- No URL or secret in this file: they are read from Supabase Vault. Once
-- per project, run in the SQL Editor (do not commit the filled-in values):
--
--   select vault.create_secret(
--     'https://<PROJECT_REF>.supabase.co/functions/v1/send-push-notification',
--     'push_function_url');
--   select vault.create_secret('<WEBHOOK_SECRET>', 'push_webhook_secret');
--
-- Without those two secrets the trigger does nothing. It can never make a
-- confirm or cancel fail: pg_net only queues the request, and any error is
-- turned into a warning.
--
-- Safe to run more than once, and on a database with real data (it only
-- adds a function and a trigger; no rows are changed).
-- ============================================================================

CREATE OR REPLACE FUNCTION public._push_settlement_update()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'push_function_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'push_webhook_secret';
  if v_url is null or v_secret is null then
    return new; -- not set up on this project
  end if;

  perform net.http_post(
    url := v_url,
    body := jsonb_build_object(
      'type', 'UPDATE',
      'table', TG_TABLE_NAME,
      'schema', TG_TABLE_SCHEMA,
      'record', to_jsonb(new),
      'old_record', to_jsonb(old)
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    timeout_milliseconds := 5000
  );
  return new;
exception when others then
  raise warning 'settlement push not queued: %', sqlerrm;
  return new;
end;
$$;

DROP TRIGGER IF EXISTS settlements_update_push ON public.settlements;
CREATE TRIGGER settlements_update_push
  AFTER UPDATE OF status ON public.settlements
  FOR EACH ROW
  WHEN (old.status = 'pending' AND new.status IN ('confirmed', 'cancelled'))
  EXECUTE FUNCTION public._push_settlement_update();
