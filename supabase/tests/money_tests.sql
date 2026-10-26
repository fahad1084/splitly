-- ============================================================================
-- Money tests for 20261027140000_money_ledger.sql (+ add_expense)
--
-- LOCAL DATABASE ONLY — it creates fake users (ali@ / bilal@ / chand@test.local).
--   supabase start
--   supabase db reset
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/tests/money_tests.sql
--   supabase stop
--
-- Every "== " line says what it expects. "debts" lists show who owes whom
-- in the test group (empty = everyone is even).
-- ============================================================================
\set ON_ERROR_STOP off
\set ALI   '''a1000000-0000-0000-0000-0000000000a1'''
\set BILAL '''b1000000-0000-0000-0000-0000000000b1'''
\set CHAND '''c1000000-0000-0000-0000-0000000000c1'''
\set G     '''91000000-0000-0000-0000-000000000091'''
\set AS_ALI   'select set_config(''request.jwt.claims'', ''{"sub":"a1000000-0000-0000-0000-0000000000a1","role":"authenticated"}'', true)'
\set AS_BILAL 'select set_config(''request.jwt.claims'', ''{"sub":"b1000000-0000-0000-0000-0000000000b1","role":"authenticated"}'', true)'
\set AS_CHAND 'select set_config(''request.jwt.claims'', ''{"sub":"c1000000-0000-0000-0000-0000000000c1","role":"authenticated"}'', true)'
\set DEBTS 'select p1.full_name as debtor, p2.full_name as creditor, d.amount from public.group_debts(' :G ') d join public.profiles p1 on p1.id = d.debtor_id join public.profiles p2 on p2.id = d.creditor_id order by 1, 2'

-- ── setup (as postgres): Ali, Bilal, Chand in one PKR group ─────────────────
insert into auth.users (id, email, aud, role) values
  (:ALI, 'ali@test.local', 'authenticated', 'authenticated'),
  (:BILAL, 'bilal@test.local', 'authenticated', 'authenticated'),
  (:CHAND, 'chand@test.local', 'authenticated', 'authenticated')
on conflict (id) do nothing;
insert into public.profiles (id, full_name) values (:ALI, 'Ali'), (:BILAL, 'Bilal'), (:CHAND, 'Chand')
on conflict do nothing;
insert into public.groups (id, name, currency, created_by) values (:G, 'Flatmates', 'PKR', :ALI)
on conflict do nothing;
insert into public.group_members (group_id, user_id, role) values
  (:G, :ALI, 'admin'), (:G, :BILAL, 'member'), (:G, :CHAND, 'member')
on conflict do nothing;


-- ── 1. The Ali/Bilal example from APP_REVIEW.md §4.1 ────────────────────────
\echo '== M-1 Bilal pays 200 (Ali 100 / Bilal 100), Ali pays 120 (Ali 60 / Bilal 60) → Ali owes Bilal 40'
begin; set local role authenticated; :AS_BILAL;
select public.add_expense(:G, :BILAL, 'Dinner', 200, jsonb_build_array(
  jsonb_build_object('user_id', :ALI, 'amount_owed', 100), jsonb_build_object('user_id', :BILAL, 'amount_owed', 100))) is not null as dinner;
commit;
begin; set local role authenticated; :AS_ALI;
select public.add_expense(:G, :ALI, 'Petrol', 120, jsonb_build_array(
  jsonb_build_object('user_id', :ALI, 'amount_owed', 60), jsonb_build_object('user_id', :BILAL, 'amount_owed', 60))) is not null as petrol;
commit;
:DEBTS;

\echo '== M-2 Ali records paying 40 → status pending, debt is STILL 40 (pending does not count)'
begin; set local role authenticated; :AS_ALI;
select public.record_settlement(:G, :ALI, :BILAL, 40) as s1 \gset
commit;
select status from public.settlements where id = :'s1';
:DEBTS;

\echo '== M-3 get_my_debts shows the 40 as pending_amount (expect amount 40, pending 40)'
begin; set local role authenticated; :AS_ALI;
select amount, pending_amount from public.get_my_debts() where group_id = :G;
rollback;

\echo '== M-4 Ali (the payer) tries to confirm his own payment (expect ERROR NOT_ALLOWED)'
begin; set local role authenticated; :AS_ALI;
select public.confirm_settlement(:'s1');
rollback;

\echo '== M-5 Chand (not involved) tries to confirm (expect ERROR NOT_ALLOWED)'
begin; set local role authenticated; :AS_CHAND;
select public.confirm_settlement(:'s1');
rollback;

\echo '== M-6 Bilal confirms → Ali and Bilal are EVEN (expect an EMPTY debts list)'
begin; set local role authenticated; :AS_BILAL;
select public.confirm_settlement(:'s1');
commit;
:DEBTS;

\echo '== M-7 confirming again (expect ERROR NOT_PENDING)'
begin; set local role authenticated; :AS_BILAL;
select public.confirm_settlement(:'s1');
rollback;

\echo '== M-8 Ali got an in-app notification "Bilal confirmed your payment of PKR 40.00"'
select body from public.notifications where entity_id = :'s1';


-- ── 2. Partial payments ─────────────────────────────────────────────────────
\echo '== P-1 Bilal pays 300 (Ali 150 / Bilal 150) → Ali owes Bilal 150'
begin; set local role authenticated; :AS_BILAL;
select public.add_expense(:G, :BILAL, 'Groceries', 300, jsonb_build_array(
  jsonb_build_object('user_id', :ALI, 'amount_owed', 150), jsonb_build_object('user_id', :BILAL, 'amount_owed', 150))) is not null as groceries;
commit;
:DEBTS;

\echo '== P-2 Ali pays 50, Bilal confirms → Ali owes Bilal 100'
begin; set local role authenticated; :AS_ALI;
select public.record_settlement(:G, :ALI, :BILAL, 50) as s2 \gset
commit;
begin; set local role authenticated; :AS_BILAL;
select public.confirm_settlement(:'s2');
commit;
:DEBTS;

\echo '== P-3 Bilal (receiver) records 30 cash himself → confirmed at once → Ali owes Bilal 70'
begin; set local role authenticated; :AS_BILAL;
select public.record_settlement(:G, :ALI, :BILAL, 30) as s3 \gset
commit;
select status from public.settlements where id = :'s3';
:DEBTS;

\echo '== P-4 Ali tries to pay 80 when he owes 70 (expect ERROR AMOUNT_TOO_HIGH)'
begin; set local role authenticated; :AS_ALI;
select public.record_settlement(:G, :ALI, :BILAL, 80);
rollback;

\echo '== P-5 Ali records 60 (pending), then 20 more (expect 2nd: ERROR AMOUNT_TOO_HIGH — only 10 left)'
begin; set local role authenticated; :AS_ALI;
select public.record_settlement(:G, :ALI, :BILAL, 60) as s4 \gset
commit;
begin; set local role authenticated; :AS_ALI;
select public.record_settlement(:G, :ALI, :BILAL, 20);
rollback;

\echo '== P-6 wrong amounts (expect ERROR INVALID_AMOUNT twice: 0 and 3 decimals)'
begin; set local role authenticated; :AS_ALI;
select public.record_settlement(:G, :ALI, :BILAL, 0);
rollback;
begin; set local role authenticated; :AS_ALI;
select public.record_settlement(:G, :ALI, :BILAL, 1.005);
rollback;

\echo '== P-7 paying someone you do not owe (expect ERROR NO_DEBT)'
begin; set local role authenticated; :AS_BILAL;
select public.record_settlement(:G, :BILAL, :ALI, 10);
rollback;

\echo '== P-8 Chand records a payment between Ali and Bilal (expect ERROR NOT_ALLOWED)'
begin; set local role authenticated; :AS_CHAND;
select public.record_settlement(:G, :ALI, :BILAL, 5);
rollback;


-- ── 3. Cancel ───────────────────────────────────────────────────────────────
\echo '== C-1 Chand tries to cancel the pending 60 (expect ERROR NOT_ALLOWED)'
begin; set local role authenticated; :AS_CHAND;
select public.cancel_settlement(:'s4');
rollback;

\echo '== C-2 Bilal cancels it → status cancelled, debt still 70'
begin; set local role authenticated; :AS_BILAL;
select public.cancel_settlement(:'s4');
commit;
select status from public.settlements where id = :'s4';
:DEBTS;

\echo '== C-3 confirm a cancelled one (expect ERROR NOT_PENDING); cancel a confirmed one (expect ERROR NOT_PENDING)'
begin; set local role authenticated; :AS_BILAL;
select public.confirm_settlement(:'s4');
rollback;
begin; set local role authenticated; :AS_BILAL;
select public.cancel_settlement(:'s2');
rollback;

\echo '== C-4 a pending payment that became too big is not confirmed (expect ERROR AMOUNT_TOO_HIGH, then Bilal owes Ali 80)'
begin; set local role authenticated; :AS_ALI;
select public.record_settlement(:G, :ALI, :BILAL, 70) as s5 \gset
commit;
-- Bilal deletes his 300 groceries. Ali's 80 of payments stay real money,
-- so now BILAL owes ALI 80 — and the pending 70 (Ali → Bilal) is too big.
begin; set local role authenticated; :AS_BILAL;
select public.delete_expense(id) from public.expenses where title = 'Groceries';
commit;
begin; set local role authenticated; :AS_BILAL;
select public.confirm_settlement(:'s5');
rollback;
begin; set local role authenticated; :AS_ALI;
select public.cancel_settlement(:'s5');
commit;
:DEBTS;


-- ── 4. Leaving a group ──────────────────────────────────────────────────────
\echo '== L-1 Chand (no debts) can leave (expect OK); add Chand back'
begin; set local role authenticated; :AS_CHAND;
select public.leave_group(:G);
commit;
select count(*) as chand_still_member from public.group_members where group_id = :G and user_id = :CHAND;
insert into public.group_members (group_id, user_id, role) values (:G, :CHAND, 'member');

\echo '== L-2 Chand owes Ali 50 → Chand cannot leave (expect ERROR HAS_UNSETTLED_DEBTS)'
begin; set local role authenticated; :AS_ALI;
select public.add_expense(:G, :ALI, 'Snacks', 100, jsonb_build_array(
  jsonb_build_object('user_id', :ALI, 'amount_owed', 50), jsonb_build_object('user_id', :CHAND, 'amount_owed', 50))) is not null as snacks;
commit;
begin; set local role authenticated; :AS_CHAND;
select public.leave_group(:G);
rollback;

\echo '== L-3 Ali (owed money) cannot leave either (expect ERROR HAS_UNSETTLED_DEBTS)'
begin; set local role authenticated; :AS_ALI;
select public.leave_group(:G);
rollback;

\echo '== L-4 leaving by deleting the membership row directly (expect DELETE 0 — blocked)'
begin; set local role authenticated; :AS_CHAND;
delete from public.group_members where group_id = :G and user_id = :CHAND;
rollback;


-- ── 5. Exact splits (100 three ways, percentages) ───────────────────────────
\echo '== S-1 100 split 3 ways as 33.34 / 33.33 / 33.33 (expect OK)'
begin; set local role authenticated; :AS_ALI;
select public.add_expense(:G, :ALI, 'Pizza', 100, jsonb_build_array(
  jsonb_build_object('user_id', :ALI, 'amount_owed', 33.34),
  jsonb_build_object('user_id', :BILAL, 'amount_owed', 33.33),
  jsonb_build_object('user_id', :CHAND, 'amount_owed', 33.33))) is not null as pizza;
rollback;

\echo '== S-2 100 split as 33.33 x 3 = 99.99 (expect ERROR SPLITS_DONT_ADD_UP)'
begin; set local role authenticated; :AS_ALI;
select public.add_expense(:G, :ALI, 'Pizza', 100, jsonb_build_array(
  jsonb_build_object('user_id', :ALI, 'amount_owed', 33.33),
  jsonb_build_object('user_id', :BILAL, 'amount_owed', 33.33),
  jsonb_build_object('user_id', :CHAND, 'amount_owed', 33.33)));
rollback;

\echo '== S-3 percentage 33.33/33.33/33.33 % of 1000 as the app sends it: 333.34 / 333.33 / 333.33 (expect OK)'
begin; set local role authenticated; :AS_ALI;
select public.add_expense(:G, :ALI, 'Bill', 1000, jsonb_build_array(
  jsonb_build_object('user_id', :ALI, 'amount_owed', 333.34),
  jsonb_build_object('user_id', :BILAL, 'amount_owed', 333.33),
  jsonb_build_object('user_id', :CHAND, 'amount_owed', 333.33)), 'other', 'percentage') is not null as bill;
rollback;


-- ── 6. Locked doors ─────────────────────────────────────────────────────────
\echo '== X-1 outsider asks for this group''s debts (expect ERROR NOT_A_MEMBER)'
insert into auth.users (id, email, aud, role) values ('d1000000-0000-0000-0000-0000000000d1', 'out@test.local', 'authenticated', 'authenticated') on conflict do nothing;
insert into public.profiles (id, full_name) values ('d1000000-0000-0000-0000-0000000000d1', 'Outsider') on conflict do nothing;
begin; set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"d1000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
select * from public.group_debts(:G);
rollback;

\echo '== X-2 logged-out caller asks for debts (expect ERROR NOT_A_MEMBER)'
begin; set local role anon; select set_config('request.jwt.claims', '{"role":"anon"}', true);
select * from public.group_debts(:G);
rollback;

\echo '== X-3 a user calls the reminder function (expect ERROR NOT_ALLOWED)'
begin; set local role authenticated; :AS_ALI;
select * from public.debts_for_reminders();
rollback;

\echo '== X-4 the service role (Edge Function) can (expect 2 rows in Flatmates: 80 and 50)'
begin; select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select group_name, currency, amount from public.debts_for_reminders() where group_id = :G;
rollback;

\echo '== X-5 direct insert of a settlement / direct split update (expect ERROR permission denied, twice)'
begin; set local role authenticated; :AS_BILAL;
insert into public.settlements (group_id, paid_by, paid_to, amount, status) values (:G, :ALI, :BILAL, 1, 'confirmed');
rollback;
begin; set local role authenticated; :AS_BILAL;
update public.expense_splits set is_settled = true;
rollback;

\echo '== X-6 marking splits "settled" no longer changes any balance (expect unchanged: Bilal owes Ali 80, Chand owes Ali 50)'
update public.expense_splits set is_settled = true
 where expense_id in (select id from public.expenses where group_id = :G);
:DEBTS;
