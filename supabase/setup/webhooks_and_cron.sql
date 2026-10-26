-- ============================================================================
-- Splitly — Database Webhooks + pg_cron jobs (exported from the live project
-- on 2026-10-27).
--
-- This is NOT a migration on purpose: it contains your project URL and the
-- webhook secret, which are different for every project and must never be
-- committed. Run it BY HAND, ONCE, on a NEW project, after the migrations:
--
--   1. Replace every <PROJECT_REF>     with the new project's ref
--      (Dashboard → Project Settings → General → Reference ID).
--   2. Replace every <WEBHOOK_SECRET>  with the SAME value you set as the
--      WEBHOOK_SECRET Edge Function secret (`supabase secrets set ...`).
--   3. Paste into Dashboard → SQL Editor and run. Do not save the filled-in
--      copy into the repo.
--
-- Do NOT run this on the live project — it already has all of these.
-- ============================================================================

-- ── Database Webhooks → send-push-notification ──────────────────────────────
-- (They show up in Dashboard → Integrations → Database Webhooks.)

CREATE OR REPLACE TRIGGER "notify-new-expense" AFTER INSERT ON public.expenses
  FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request(
    'https://<PROJECT_REF>.supabase.co/functions/v1/send-push-notification', 'POST',
    '{"Content-type":"application/json","x-webhook-secret":"<WEBHOOK_SECRET>"}', '{}', '5000');

CREATE OR REPLACE TRIGGER "notify-new-member" AFTER INSERT ON public.group_members
  FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request(
    'https://<PROJECT_REF>.supabase.co/functions/v1/send-push-notification', 'POST',
    '{"Content-type":"application/json","x-webhook-secret":"<WEBHOOK_SECRET>"}', '{}', '5000');

CREATE OR REPLACE TRIGGER "notify-new-message" AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request(
    'https://<PROJECT_REF>.supabase.co/functions/v1/send-push-notification', 'POST',
    '{"Content-type":"application/json","x-webhook-secret":"<WEBHOOK_SECRET>"}', '{}', '5000');

CREATE OR REPLACE TRIGGER "notify-new-settlement" AFTER INSERT ON public.settlements
  FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request(
    'https://<PROJECT_REF>.supabase.co/functions/v1/send-push-notification', 'POST',
    '{"Content-type":"application/json","x-webhook-secret":"<WEBHOOK_SECRET>"}', '{}', '5000');

-- ── pg_cron jobs ────────────────────────────────────────────────────────────
-- (They show up in Dashboard → Integrations → Cron. Times are UTC:
--  02:00 UTC = 07:00 PKT, 10:00 UTC = 15:00 PKT.)
-- cron.schedule() with an existing job name updates that job, so running
-- this twice does not create duplicates.

SELECT cron.schedule(
  'generate-recurring-expenses',
  '0 2 * * *',
  $$select public.generate_recurring_expenses();$$
);

SELECT cron.schedule(
  'debt-reminders-daily',
  '0 10 * * *',
  $$
  select net.http_post(
    url := 'https://<PROJECT_REF>.supabase.co/functions/v1/send-debt-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', '<WEBHOOK_SECRET>'
    ),
    body := '{}'::jsonb
  );
  $$
);
