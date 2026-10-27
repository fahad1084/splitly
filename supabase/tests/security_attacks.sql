-- ============================================================================
-- Security attack tests for 20261027120000_security_fixes.sql
--
-- LOCAL DATABASE ONLY — it creates fake users (a@ / b@ / c@test.local).
-- Never run it on the live or test project.
--
-- How to run (Docker Desktop must be running):
--   supabase start
--   supabase db reset          # fresh local DB from supabase/migrations
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/tests/security_attacks.sql
--   supabase stop
--
-- Read the output: every "== ATTACK" line must show the error / 0 rows it
-- expects, every "== OK" line must succeed.
-- ============================================================================
-- A = group creator, B = normal member, C = outsider.
\set ON_ERROR_STOP off
\set A '''aaaaaaaa-0000-0000-0000-00000000000a'''
\set B '''bbbbbbbb-0000-0000-0000-00000000000b'''
\set C '''cccccccc-0000-0000-0000-00000000000c'''
\set G '''99999999-0000-0000-0000-000000000009'''
\set E '''eeeeeeee-0000-0000-0000-00000000000e'''

-- ── setup (as postgres) ──────────────────────────────────────────────────────
insert into auth.users (id, email, aud, role) values
  (:A, 'a@test.local', 'authenticated', 'authenticated'),
  (:B, 'b@test.local', 'authenticated', 'authenticated'),
  (:C, 'c@test.local', 'authenticated', 'authenticated')
on conflict (id) do nothing;
insert into public.profiles (id, full_name) values (:A,'A'),(:B,'B'),(:C,'C') on conflict do nothing;

\echo '== OK-1 A creates group + adds self as admin (expect INSERT 0 1 twice)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
insert into public.groups (id, name, created_by, invite_code) values (:G, 'Flat', :A, 'abcd1234');
insert into public.group_members (group_id, user_id, role) values (:G, :A, 'admin');
commit;

\echo '== OK-2 B joins with the code (expect 1 row, already_member = f), then again (already_member = t)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select * from public.join_group_by_code('ABCD1234 ');
select * from public.join_group_by_code('abcd1234');
commit;

\echo '== ATTACK-1a C inserts self into the group directly (expect ERROR row-level security)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-00000000000c","role":"authenticated"}', true);
insert into public.group_members (group_id, user_id, role) values (:G, :C, 'member');
rollback;

\echo '== ATTACK-1b C uses a wrong code (expect 0 rows)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-00000000000c","role":"authenticated"}', true);
select * from public.join_group_by_code('zzzz9999');
rollback;

\echo '== ATTACK-2a B deletes own membership row and re-inserts as admin (expect DELETE 0 — leave only via leave_group — then ERROR row-level security)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
delete from public.group_members where group_id = :G and user_id = :B;
insert into public.group_members (group_id, user_id, role) values (:G, :B, 'admin');
rollback;

\echo '== ATTACK-2b B (member) promotes self (expect UPDATE 0)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
update public.group_members set role = 'admin' where group_id = :G and user_id = :B;
rollback;

\echo '== ATTACK-2c A (admin) moves a membership to another user (expect ERROR permission denied for table)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
update public.group_members set user_id = :C where group_id = :G and user_id = :B;
rollback;

\echo '== ATTACK-2d A sets a made-up role (expect ERROR check constraint)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
update public.group_members set role = 'owner' where group_id = :G and user_id = :B;
rollback;

\echo '== OK-3 A adds expense 100 paid by A, split A 50 / B 50 via add_expense (expect an id)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select public.add_expense(:G, :A, 'Dinner', 100,
  jsonb_build_array(jsonb_build_object('user_id', :A, 'amount_owed', 50),
                    jsonb_build_object('user_id', :B, 'amount_owed', 50))) as eid \gset
commit;
\set E '''' :eid ''''

\echo '== ATTACK-3a B (debtor) marks own split settled (expect ERROR permission denied — splits are never updated directly)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
update public.expense_splits set is_settled = true where expense_id = :E and user_id = :B;
rollback;

\echo '== ATTACK-3b A (payer) lowers B''s amount (expect ERROR permission denied)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
update public.expense_splits set amount_owed = 1 where expense_id = :E and user_id = :B;
rollback;

\echo '== ATTACK-3c B inserts a settlement directly (expect ERROR permission denied — record_settlement only)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
insert into public.settlements (group_id, paid_by, paid_to, amount) values (:G, :B, :A, 50);
rollback;

\echo '== OK-4 A (creditor) records that B paid 50 via record_settlement (expect status confirmed)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select public.record_settlement(:G, :B, :A, 50) as sid \gset
select status from public.settlements where id = :'sid';
rollback;

\echo '== ATTACK-4a B adds expense paid by outsider C (expect ERROR PAYER_NOT_MEMBER)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select public.add_expense(:G, :C, 'Fake', 100, jsonb_build_array(jsonb_build_object('user_id', :B, 'amount_owed', 100)));
rollback;

\echo '== ATTACK-4b B adds negative expense (expect ERROR INVALID_AMOUNT)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select public.add_expense(:G, :B, 'Neg', -50, jsonb_build_array(jsonb_build_object('user_id', :B, 'amount_owed', -50)));
rollback;

\echo '== ATTACK-4c B puts outsider C into a split (expect ERROR SPLIT_USER_NOT_MEMBER)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select public.add_expense(:G, :B, 'X', 20, jsonb_build_array(jsonb_build_object('user_id', :B, 'amount_owed', 10), jsonb_build_object('user_id', :C, 'amount_owed', 10)));
rollback;

\echo '== ATTACK-4d B splits the same person twice (expect ERROR DUPLICATE_SPLIT)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select public.add_expense(:G, :B, 'X', 20, jsonb_build_array(jsonb_build_object('user_id', :B, 'amount_owed', 10), jsonb_build_object('user_id', :B, 'amount_owed', 10)));
rollback;

\echo '== ATTACK-4f B inserts an expense / a split directly, skipping the RPC (expect ERROR permission denied, twice)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
insert into public.expenses (group_id, paid_by, title, amount) values (:G, :B, 'Direct', 100);
rollback;
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
insert into public.expense_splits (expense_id, user_id, amount_owed) values (:E, :B, 10);
rollback;

\echo '== ATTACK-4e A (payer) edits own expense directly (expect UPDATE 0 — no update policy any more)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
update public.expenses set title = 'changed' where id = :E;
rollback;

\echo '== ATTACK-5a logged-out caller deletes the group (expect ERROR Not authenticated)'
begin; set local role anon; select set_config('request.jwt.claims', '{"role":"anon"}', true);
select public.delete_group_permanently(:G);
rollback;

\echo '== ATTACK-5b B (not creator) deletes the group (expect ERROR Only the group creator...)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select public.delete_group_permanently(:G);
rollback;

\echo '== ATTACK-5c B renames / archives the group (expect UPDATE 0)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
update public.groups set name = 'hacked', is_archived = true where id = :G;
rollback;

\echo '== ATTACK-5d logged-in user runs recurring job by hand (expect ERROR Not allowed)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select public.generate_recurring_expenses();
rollback;

-- storage objects (as postgres) to read back
insert into storage.objects (bucket_id, name, owner, owner_id) values
  ('chat-attachments', '99999999-0000-0000-0000-000000000009/photo.jpg', 'aaaaaaaa-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-00000000000a')
on conflict do nothing;

\echo '== ATTACK-6a chat-attachments bucket is private (expect f)'
select public from storage.buckets where id = 'chat-attachments';

\echo '== OK-6 member B can see the chat file (expect 1)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select count(*) from storage.objects where bucket_id = 'chat-attachments';
rollback;

\echo '== ATTACK-6b outsider C cannot see it (expect 0)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-00000000000c","role":"authenticated"}', true);
select count(*) from storage.objects where bucket_id = 'chat-attachments';
rollback;

\echo '== ATTACK-6c C uploads into the group''s chat folder (expect ERROR row-level security)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-00000000000c","role":"authenticated"}', true);
insert into storage.objects (bucket_id, name) values ('chat-attachments', '99999999-0000-0000-0000-000000000009/evil.jpg');
rollback;

\echo '== ATTACK-6d C overwrites B''s avatar (expect ERROR row-level security)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-00000000000c","role":"authenticated"}', true);
insert into storage.objects (bucket_id, name) values ('avatars', 'bbbbbbbb-0000-0000-0000-00000000000b/avatar.jpg');
rollback;

\echo '== ATTACK-6e B (not creator) uploads a group photo (expect ERROR row-level security)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
insert into storage.objects (bucket_id, name) values ('group-photos', '99999999-0000-0000-0000-000000000009/photo.jpg');
rollback;

\echo '== OK-7 C uploads own avatar (expect INSERT 0 1)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-00000000000c","role":"authenticated"}', true);
insert into storage.objects (bucket_id, name) values ('avatars', 'cccccccc-0000-0000-0000-00000000000c/avatar.jpg');
rollback;

\echo '== ATTACK-5e logged-out caller probes an invite code (expect 0 rows)'
begin; set local role anon; select set_config('request.jwt.claims', '{"role":"anon"}', true);
select * from public.get_group_preview_by_invite_code('abcd1234');
rollback;

\echo '== OK-8 cron (no JWT, as postgres) can still run the recurring job (expect empty result, no error)'
select public.generate_recurring_expenses();

\echo '== OK-9 admin A promotes B (expect UPDATE 1), then B tries to leave while owing A 50 (expect ERROR HAS_UNSETTLED_DEBTS)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
update public.group_members set role = 'admin' where group_id = '99999999-0000-0000-0000-000000000009' and user_id = 'bbbbbbbb-0000-0000-0000-00000000000b';
rollback;
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select public.leave_group('99999999-0000-0000-0000-000000000009');
rollback;

\echo '== OK-10 admin A removes B, who owes A 50 (expect ERROR HAS_UNSETTLED_DEBTS); a direct delete does nothing (expect DELETE 0)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select public.remove_member('99999999-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-00000000000b');
rollback;
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
delete from public.group_members where group_id = '99999999-0000-0000-0000-000000000009' and user_id = 'bbbbbbbb-0000-0000-0000-00000000000b';
rollback;

\echo '== ATTACK-2e member B removes creator A (expect DELETE 0)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
delete from public.group_members where group_id = '99999999-0000-0000-0000-000000000009' and user_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
rollback;


-- ============================================================================
-- Step 4 — transactions (20261027130000_transactions.sql)
-- ============================================================================

\echo '== OK-11 C creates a group with create_group (expect an id, C is admin)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-00000000000c","role":"authenticated"}', true);
select public.create_group('C group', null, 'USD') is not null as created;
select role from public.group_members where user_id = :C;
rollback;

\echo '== TX-1 splits do not add up: 100 vs 99.99 (expect ERROR SPLITS_DONT_ADD_UP, and NO expense saved)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select public.add_expense(:G, :A, 'Short', 100, jsonb_build_array(
  jsonb_build_object('user_id', :A, 'amount_owed', 33.33),
  jsonb_build_object('user_id', :B, 'amount_owed', 66.66)));
rollback;
select count(*) as expenses_named_short from public.expenses where title = 'Short';

\echo '== TX-2 nobody in the split (expect ERROR NO_MEMBERS)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select public.add_expense(:G, :A, 'Empty', 100, '[]'::jsonb);
rollback;

\echo '== TX-3 outsider C adds to a group they are not in (expect ERROR NOT_A_MEMBER)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-00000000000c","role":"authenticated"}', true);
select public.add_expense(:G, :C, 'Sneaky', 10, jsonb_build_array(jsonb_build_object('user_id', :C, 'amount_owed', 10)));
rollback;

\echo '== TX-4 a failing split rolls back the whole expense (expect ERROR, then 0 rows for both)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
-- 2nd split has 3 decimals → INVALID_SPLIT_AMOUNT before anything is written
select public.add_expense(:G, :A, 'Rollback', 10, jsonb_build_array(
  jsonb_build_object('user_id', :A, 'amount_owed', 5),
  jsonb_build_object('user_id', :B, 'amount_owed', 4.999)));
rollback;
select (select count(*) from public.expenses where title = 'Rollback') as expenses,
       (select count(*) from public.expense_splits s join public.expenses e on e.id = s.expense_id where e.title = 'Rollback') as splits;

\echo '== TX-5 monthly recurring on 31 Jan lands on 28/29 Feb (expect 2027-02-28)'
select (timestamptz '2027-01-31 12:00+00' + interval '1 month')::date as next_after_31_jan;

\echo '== TX-6 currency comes from the group, not the caller (expect PKR)'
select currency from public.expenses where id = :E;

\echo '== TX-7 B (not the payer) deletes A''s expense (expect ERROR NOT_ALLOWED)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select public.delete_expense(:E);
rollback;

\echo '== TX-8 A (payer) deletes it — splits go too (expect 0 expenses, 0 splits)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select public.delete_expense(:E);
select (select count(*) from public.expenses where id = :E) as expenses,
       (select count(*) from public.expense_splits where expense_id = :E) as splits;
rollback;

\echo '== TX-9 storage blocks SQL deletes (expect ERROR "Use the Storage API" twice — delete rules are tested through the Storage API instead)'
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-00000000000b","role":"authenticated"}', true);
delete from storage.objects where bucket_id = 'chat-attachments' and name = '99999999-0000-0000-0000-000000000009/photo.jpg';
rollback;
begin; set local role authenticated; select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
delete from storage.objects where bucket_id = 'chat-attachments' and name = '99999999-0000-0000-0000-000000000009/photo.jpg';
rollback;
