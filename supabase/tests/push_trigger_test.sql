-- ============================================================================
-- Tests for the settlements_update_push trigger
-- (supabase/migrations/20261029000000_settlement_update_push.sql).
--
-- LOCAL DATABASE ONLY — it creates fake users (dania@ / emad@test.local) and
-- fake Vault secrets (removed again at the end).
--   supabase start
--   supabase db reset
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/tests/push_trigger_test.sql
--   supabase stop
--
-- pg_net only QUEUES a request (net.http_request_queue) and sends it after
-- COMMIT, so each check counts the queue inside the open transaction.
-- Every "== " line says what it expects.
-- ============================================================================
\set ON_ERROR_STOP off
\set DANIA '''d1000000-0000-0000-0000-0000000000d1'''
\set EMAD  '''e1000000-0000-0000-0000-0000000000e1'''
\set G     '''92000000-0000-0000-0000-000000000092'''
\set URL   '''http://127.0.0.1:9/functions/v1/send-push-notification'''
\set AS_DANIA 'select set_config(''request.jwt.claims'', ''{"sub":"d1000000-0000-0000-0000-0000000000d1","role":"authenticated"}'', true)'
\set AS_EMAD  'select set_config(''request.jwt.claims'', ''{"sub":"e1000000-0000-0000-0000-0000000000e1","role":"authenticated"}'', true)'
\set QUEUED 'select count(*) as queued from net.http_request_queue where url = ' :URL
\set LAST_BODY 'select b->>''type'' as type, b->>''table'' as tbl, b->''old_record''->>''status'' as old_status, b->''record''->>''status'' as new_status, headers->>''x-webhook-secret'' as secret from (select convert_from(body, ''utf8'')::jsonb as b, headers from net.http_request_queue where url = ' :URL ' order by id desc limit 1) q'

-- ── setup (as postgres): Dania owes Emad 100 ────────────────────────────────
insert into auth.users (id, email, aud, role) values
  (:DANIA, 'dania@test.local', 'authenticated', 'authenticated'),
  (:EMAD, 'emad@test.local', 'authenticated', 'authenticated')
on conflict (id) do nothing;
insert into public.profiles (id, full_name) values (:DANIA, 'Dania'), (:EMAD, 'Emad')
on conflict do nothing;
insert into public.groups (id, name, currency, created_by) values (:G, 'Trip', 'PKR', :DANIA)
on conflict do nothing;
insert into public.group_members (group_id, user_id, role) values
  (:G, :DANIA, 'admin'), (:G, :EMAD, 'member')
on conflict do nothing;
begin; set local role authenticated; :AS_EMAD;
select public.add_expense(:G, :EMAD, 'Hotel', 200, jsonb_build_array(
  jsonb_build_object('user_id', :DANIA, 'amount_owed', 100), jsonb_build_object('user_id', :EMAD, 'amount_owed', 100))) is not null as hotel;
commit;

\echo '== T-1 NO Vault secrets: Emad confirms a pending payment (expect confirm OK, queued 0)'
begin; set local role authenticated; :AS_DANIA;
select public.record_settlement(:G, :DANIA, :EMAD, 10) as s0 \gset
commit;
begin; set local role authenticated; :AS_EMAD;
select 'ok' as confirmed from (select public.confirm_settlement(:'s0')) x;
reset role;
:QUEUED;
commit;
select status from public.settlements where id = :'s0';

-- fake secrets (as postgres)
select vault.create_secret(:URL, 'push_function_url') is not null as url_secret;
select vault.create_secret('test-secret', 'push_webhook_secret') is not null as webhook_secret;

\echo '== T-2 Emad confirms → queued 1: UPDATE settlements pending → confirmed, secret test-secret'
begin; set local role authenticated; :AS_DANIA;
select public.record_settlement(:G, :DANIA, :EMAD, 30) as s1 \gset
commit;
begin; set local role authenticated; :AS_EMAD;
select 'ok' as confirmed from (select public.confirm_settlement(:'s1')) x;
reset role;
:QUEUED;
:LAST_BODY;
rollback;

\echo '== T-3 Dania cancels her pending payment → queued 1: pending → cancelled'
begin; set local role authenticated; :AS_DANIA;
select 'ok' as cancelled from (select public.cancel_settlement(:'s1')) x;
reset role;
:QUEUED;
:LAST_BODY;
rollback;

\echo '== T-4 Emad records "I got paid" (INSERT confirmed) → queued 0 (the INSERT webhook handles it)'
begin; set local role authenticated; :AS_EMAD;
select public.record_settlement(:G, :DANIA, :EMAD, 20) is not null as recorded;
reset role;
:QUEUED;
rollback;

\echo '== T-5 a status UPDATE that is not pending → confirmed/cancelled → queued 0'
begin;
update public.settlements set status = status where id = :'s0';
:QUEUED;
rollback;

\echo '== T-6 the money still adds up: Dania owes Emad 90 (100 − the 10 confirmed in T-1)'
select d.amount from public.group_debts(:G) d;

-- clean up the fake secrets
delete from vault.secrets where name in ('push_function_url', 'push_webhook_secret');
