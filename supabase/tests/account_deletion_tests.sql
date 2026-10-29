-- ============================================================================
-- Account deletion tests (20261031000100_account_deletion.sql)
--
-- Runs in ONE block that always ends with an error, which undoes every
-- change, so it's safe on splitly-test too. The error text IS the result:
--     RESULT: 15 passed, failed: none
--
--   supabase db query --local -f supabase/tests/account_deletion_tests.sql
--
-- Ali is the one who deletes the account.
--   g1 Flat   (Ali created): Ali admin, Bilal (joined first), Chand
--   g2 Trip   (Bilal created): Bilal, Ali
--   g3 Solo   (Ali created): only Ali
--   g4 Old    (Bilal created, ARCHIVED): Bilal, Ali
--   g5 Office (Ali created): Ali admin, Dana (joined first), Erin admin
-- ============================================================================
do $$
declare
  ali   uuid := 'a5000000-0000-0000-0000-0000000000a1';
  bilal uuid := 'b5000000-0000-0000-0000-0000000000b1';
  chand uuid := 'c5000000-0000-0000-0000-0000000000c1';
  dana  uuid := 'd5000000-0000-0000-0000-0000000000d1';
  erin  uuid := 'e5000000-0000-0000-0000-0000000000e1';
  outsider uuid := 'f5000000-0000-0000-0000-0000000000f1';
  g1 uuid := '97000000-0000-0000-0000-000000000001';
  g2 uuid := '97000000-0000-0000-0000-000000000002';
  g3 uuid := '97000000-0000-0000-0000-000000000003';
  g4 uuid := '97000000-0000-0000-0000-000000000004';
  g5 uuid := '97000000-0000-0000-0000-000000000005';
  r1 uuid; r2 uuid;
  v_n int;
  v_expenses int; v_splits int; v_settlements int; v_messages int;
  v_chand_debt numeric;
  ok int := 0;
  fails text := '';
begin
  -- ── setup ─────────────────────────────────────────────────────────────────
  insert into auth.users (id, email, aud, role) values
    (ali, 'ad-ali@test.local', 'authenticated', 'authenticated'),
    (bilal, 'ad-bilal@test.local', 'authenticated', 'authenticated'),
    (chand, 'ad-chand@test.local', 'authenticated', 'authenticated'),
    (dana, 'ad-dana@test.local', 'authenticated', 'authenticated'),
    (erin, 'ad-erin@test.local', 'authenticated', 'authenticated'),
    (outsider, 'ad-out@test.local', 'authenticated', 'authenticated');
  insert into public.profiles (id, full_name, phone, avatar_url) values
    (ali, 'Ali', '0300', 'https://example.test/avatars/a5/photo.jpg'),
    (bilal, 'Bilal', null, null), (chand, 'Chand', null, null),
    (dana, 'Dana', null, null), (erin, 'Erin', null, null), (outsider, 'Out', null, null)
    on conflict (id) do update set full_name = excluded.full_name,
      phone = excluded.phone, avatar_url = excluded.avatar_url;
  insert into public.groups (id, name, currency, created_by) values
    (g1, 'Flat', 'PKR', ali), (g2, 'Trip', 'PKR', bilal), (g3, 'Solo', 'PKR', ali),
    (g4, 'Old', 'PKR', bilal), (g5, 'Office', 'PKR', ali);
  insert into public.group_members (group_id, user_id, role, joined_at) values
    (g1, bilal, 'member', now() - interval '3 days'),
    (g1, ali, 'admin', now() - interval '2 days'),
    (g1, chand, 'member', now() - interval '1 day'),
    (g2, bilal, 'admin', now() - interval '3 days'), (g2, ali, 'member', now()),
    (g3, ali, 'admin', now()),
    (g4, bilal, 'admin', now() - interval '3 days'), (g4, ali, 'member', now()),
    (g5, dana, 'member', now() - interval '9 days'),
    (g5, ali, 'admin', now() - interval '5 days'),
    (g5, erin, 'admin', now() - interval '1 day');

  -- g1: Bilal paid 100 (Ali 50 / Bilal 50); recurring R1 90 with Ali in it,
  --     R2 60 without Ali → Ali owes Bilal 80, Chand owes Bilal 60
  perform set_config('request.jwt.claims', json_build_object('sub', bilal, 'role', 'authenticated')::text, true);
  perform public.add_expense(p_group_id => g1, p_paid_by => bilal, p_title => 'Rent',
    p_amount => 100, p_splits => jsonb_build_array(
      jsonb_build_object('user_id', ali, 'amount_owed', 50),
      jsonb_build_object('user_id', bilal, 'amount_owed', 50)));
  r1 := public.add_expense(p_group_id => g1, p_paid_by => bilal, p_title => 'Internet',
    p_amount => 90, p_is_recurring => true, p_recur_every => 'monthly',
    p_splits => jsonb_build_array(
      jsonb_build_object('user_id', ali, 'amount_owed', 30),
      jsonb_build_object('user_id', bilal, 'amount_owed', 30),
      jsonb_build_object('user_id', chand, 'amount_owed', 30)));
  r2 := public.add_expense(p_group_id => g1, p_paid_by => bilal, p_title => 'Water',
    p_amount => 60, p_is_recurring => true, p_recur_every => 'monthly',
    p_splits => jsonb_build_array(
      jsonb_build_object('user_id', bilal, 'amount_owed', 30),
      jsonb_build_object('user_id', chand, 'amount_owed', 30)));
  -- g4 (archived later): Bilal paid 60 → Ali owes Bilal 30
  perform public.add_expense(p_group_id => g4, p_paid_by => bilal, p_title => 'Old bill',
    p_amount => 60, p_splits => jsonb_build_array(
      jsonb_build_object('user_id', ali, 'amount_owed', 30),
      jsonb_build_object('user_id', bilal, 'amount_owed', 30)));
  update public.groups set is_archived = true where id = g4;
  -- g2: Ali paid 100 → Bilal owes Ali 50
  perform set_config('request.jwt.claims', json_build_object('sub', ali, 'role', 'authenticated')::text, true);
  perform public.add_expense(p_group_id => g2, p_paid_by => ali, p_title => 'Taxi',
    p_amount => 100, p_splits => jsonb_build_array(
      jsonb_build_object('user_id', ali, 'amount_owed', 50),
      jsonb_build_object('user_id', bilal, 'amount_owed', 50)));
  insert into public.messages (group_id, sender_id, content) values (g1, ali, 'Hi from Ali');
  insert into public.notifications (user_id, type, title, body, group_id) values
    (ali, 'expense', 'Flat', 'Test', g1);

  -- ── refused while money is open ───────────────────────────────────────────
  -- A1 Ali owes (g1, g4) and is owed (g2) → refused, nothing changed
  begin
    perform public.delete_own_account();
    fails := fails || ' A1(deleted)';
  exception when others then
    if sqlerrm = 'HAS_UNSETTLED_DEBTS'
       and (select full_name from public.profiles where id = ali) = 'Ali'
       and (select count(*) from public.group_members where user_id = ali) = 5
    then ok := ok + 1; else fails := fails || ' A1(' || sqlerrm || ')'; end if;
  end;

  -- Settle g1 and g2; only the ARCHIVED group g4 still has a debt
  perform set_config('request.jwt.claims', json_build_object('sub', bilal, 'role', 'authenticated')::text, true);
  perform public.record_settlement(g1, ali, bilal, 80);   -- receiver records → confirmed
  perform set_config('request.jwt.claims', json_build_object('sub', ali, 'role', 'authenticated')::text, true);
  perform public.record_settlement(g2, bilal, ali, 50);

  -- A2 a debt only in an archived group still blocks it
  begin
    perform public.delete_own_account();
    fails := fails || ' A2(deleted)';
  exception when others then
    if sqlerrm = 'HAS_UNSETTLED_DEBTS' then ok := ok + 1; else fails := fails || ' A2(' || sqlerrm || ')'; end if;
  end;

  perform set_config('request.jwt.claims', json_build_object('sub', bilal, 'role', 'authenticated')::text, true);
  perform public.record_settlement(g4, ali, bilal, 30);

  -- A3 before deleting: an outsider can't read Ali's profile
  perform set_config('request.jwt.claims', json_build_object('sub', outsider, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into v_n from public.profiles where id = ali;
  execute 'reset role';
  if v_n = 0 then ok := ok + 1; else fails := fails || ' A3'; end if;
  perform set_config('request.jwt.claims', '{}', true);   -- back to "no user"

  -- Others' history before
  select count(*) into v_expenses from public.expenses where group_id in (g1, g2, g4, g5);
  select count(*) into v_splits from public.expense_splits s join public.expenses e on e.id = s.expense_id
   where e.group_id in (g1, g2, g4, g5);
  select count(*) into v_settlements from public.settlements where group_id in (g1, g2, g4, g5);
  select count(*) into v_messages from public.messages where group_id in (g1, g2, g4, g5);
  select amount into v_chand_debt from public.group_debts(g1)
   where debtor_id = chand and creditor_id = bilal;

  -- ── delete ────────────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', ali, 'role', 'authenticated')::text, true);
  perform public.delete_own_account();
  perform set_config('request.jwt.claims', '{}', true);

  -- D1 anonymized, photo link cleared, marked deleted
  if exists (select 1 from public.profiles where id = ali and full_name = 'Deleted User'
               and phone is null and avatar_url is null and fcm_token is null
               and deleted_at is not null)
  then ok := ok + 1; else fails := fails || ' D1'; end if;

  -- D2 login blocked
  if exists (select 1 from auth.users where id = ali and email like 'deleted-%@splitly.deleted'
               and banned_until > now() and encrypted_password = '')
  then ok := ok + 1; else fails := fails || ' D2'; end if;

  -- D3 left every group
  if (select count(*) from public.group_members where user_id = ali) = 0
  then ok := ok + 1; else fails := fails || ' D3'; end if;

  -- D4 others' history unchanged: expenses, splits, payments, messages
  if (select count(*) from public.expenses where group_id in (g1, g2, g4, g5)) = v_expenses
     and (select count(*) from public.expense_splits s join public.expenses e on e.id = s.expense_id
           where e.group_id in (g1, g2, g4, g5)) = v_splits
     and (select count(*) from public.settlements where group_id in (g1, g2, g4, g5)) = v_settlements
     and (select count(*) from public.messages where group_id in (g1, g2, g4, g5)) = v_messages
  then ok := ok + 1; else fails := fails || ' D4'; end if;

  -- D5 others' balances unchanged: Chand still owes Bilal the same in g1
  if (select amount from public.group_debts(g1) where debtor_id = chand and creditor_id = bilal) = v_chand_debt
     and v_chand_debt = 60
  then ok := ok + 1; else fails := fails || ' D5(' || coalesce(v_chand_debt::text, 'none') || ')'; end if;

  -- D6 g1 (no other admin) → the longest-standing member Bilal owns it, as admin
  if (select created_by from public.groups where id = g1) = bilal
     and (select role from public.group_members where group_id = g1 and user_id = bilal) = 'admin'
     and (select role from public.group_members where group_id = g1 and user_id = chand) = 'member'
  then ok := ok + 1; else fails := fails || ' D6'; end if;

  -- D7 g5 → the other ADMIN Erin, even though Dana joined earlier
  if (select created_by from public.groups where id = g5) = erin
  then ok := ok + 1; else fails := fails || ' D7'; end if;

  -- D8 g3 (nobody else) archived; g2 (Bilal's) untouched
  if (select is_archived from public.groups where id = g3)
     and (select created_by from public.groups where id = g2) = bilal
     and not (select is_archived from public.groups where id = g2)
  then ok := ok + 1; else fails := fails || ' D8'; end if;

  -- D9 recurring with Ali in it stopped; without Ali still running
  if not (select is_recurring from public.expenses where id = r1)
     and (select next_recur_at from public.expenses where id = r1) is null
     and (select is_recurring from public.expenses where id = r2)
  then ok := ok + 1; else fails := fails || ' D9'; end if;

  -- D10 Ali's own notifications are gone, the message stays
  if (select count(*) from public.notifications where user_id = ali) = 0
     and exists (select 1 from public.messages where sender_id = ali and content = 'Hi from Ali')
  then ok := ok + 1; else fails := fails || ' D10'; end if;

  -- D11 any signed-in user can read the deleted profile (shows "Deleted User"),
  --     but still not a normal profile from outside their groups
  perform set_config('request.jwt.claims', json_build_object('sub', outsider, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into v_n from public.profiles where id = ali and full_name = 'Deleted User';
  if v_n = 1 and (select count(*) from public.profiles where id = bilal) = 0
  then ok := ok + 1; else fails := fails || ' D11(' || v_n || ')'; end if;

  -- D12 a user can't mark their own profile as deleted (would make it public)
  perform set_config('request.jwt.claims', json_build_object('sub', bilal, 'role', 'authenticated')::text, true);
  begin
    update public.profiles set deleted_at = now() where id = bilal;
    fails := fails || ' D12(changed)';
  exception when others then
    if sqlerrm = 'NOT_ALLOWED' then ok := ok + 1; else fails := fails || ' D12(' || sqlerrm || ')'; end if;
  end;
  execute 'reset role';

  raise exception 'RESULT: % passed, failed:%', ok, coalesce(nullif(fails, ''), ' none');
end $$;
