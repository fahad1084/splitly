-- ============================================================================
-- Phase 3 tests (expense date, edit expense, recurring expenses, group type)
--
-- SAFE ON splitly-test: everything runs in ONE block that always ends with
-- an error. That error undoes every change the test made (users, groups,
-- expenses), so nothing is left behind. The error text IS the result:
--     RESULT: 12 passed, failed: none
--
--   supabase db query --linked -f supabase/tests/phase3_tests.sql
-- or on the local database:
--   supabase db query --local -f supabase/tests/phase3_tests.sql
-- ============================================================================
do $$
declare
  ali   uuid := 'a3000000-0000-0000-0000-0000000000a1';
  bilal uuid := 'b3000000-0000-0000-0000-0000000000b1';
  g     uuid := '94000000-0000-0000-0000-000000000094';
  today date := (now() at time zone 'Asia/Karachi')::date;
  splits jsonb := jsonb_build_array(
    jsonb_build_object('user_id', 'a3000000-0000-0000-0000-0000000000a1', 'amount_owed', 50),
    jsonb_build_object('user_id', 'b3000000-0000-0000-0000-0000000000b1', 'amount_owed', 50));
  v_id  uuid;
  v_id2 uuid;
  v_id3 uuid;
  v_date date;
  v_n   int;
  v_amt numeric;
  ok    int := 0;
  fails text := '';
begin
  -- ── setup: Ali (admin) and Bilal in one PKR group ─────────────────────────
  insert into auth.users (id, email, aud, role) values
    (ali, 'p3-ali@test.local', 'authenticated', 'authenticated'),
    (bilal, 'p3-bilal@test.local', 'authenticated', 'authenticated');
  insert into public.profiles (id, full_name) values (ali, 'Ali'), (bilal, 'Bilal')
    on conflict (id) do nothing;
  insert into public.groups (id, name, currency, created_by) values (g, 'P3 test', 'PKR', ali);
  insert into public.group_members (group_id, user_id, role) values
    (g, ali, 'admin'), (g, bilal, 'member');
  perform set_config('request.jwt.claims',
    json_build_object('sub', ali, 'role', 'authenticated')::text, true);

  -- ── 10a: expense date ─────────────────────────────────────────────────────
  -- A1 every existing expense has a date
  select count(*) into v_n from public.expenses where expense_date is null;
  if v_n = 0 then ok := ok + 1; else fails := fails || ' A1'; end if;

  -- A2 old app call (no date) → today
  v_id := public.add_expense(p_group_id => g, p_paid_by => ali, p_title => 'Old app',
    p_amount => 100, p_splits => splits);
  select expense_date into v_date from public.expenses where id = v_id;
  if v_date = today then ok := ok + 1; else fails := fails || ' A2'; end if;

  -- A3 a date in the past is saved as given
  v_id := public.add_expense(p_group_id => g, p_paid_by => ali, p_title => 'Yesterday',
    p_amount => 100, p_splits => splits, p_expense_date => today - 1);
  select expense_date into v_date from public.expenses where id = v_id;
  if v_date = today - 1 then ok := ok + 1; else fails := fails || ' A3'; end if;

  -- A4 a date in the future → INVALID_DATE
  begin
    perform public.add_expense(p_group_id => g, p_paid_by => ali, p_title => 'Future',
      p_amount => 100, p_splits => splits, p_expense_date => today + 5);
    fails := fails || ' A4(saved)';
  exception when others then
    if sqlerrm = 'INVALID_DATE' then ok := ok + 1; else fails := fails || ' A4(' || sqlerrm || ')'; end if;
  end;

  -- A5 only ONE add_expense exists (no ambiguous old version)
  select count(*) into v_n from pg_proc
   where proname = 'add_expense' and pronamespace = 'public'::regnamespace;
  if v_n = 1 then ok := ok + 1; else fails := fails || ' A5'; end if;

  -- ── 10b: edit expense ─────────────────────────────────────────────────────
  -- Bilal pays 300, split 150/150 → Ali owes Bilal 150
  perform set_config('request.jwt.claims',
    json_build_object('sub', bilal, 'role', 'authenticated')::text, true);
  v_id := public.add_expense(p_group_id => g, p_paid_by => bilal, p_title => 'Taxi',
    p_amount => 300, p_splits => jsonb_build_array(
      jsonb_build_object('user_id', ali, 'amount_owed', 150),
      jsonb_build_object('user_id', bilal, 'amount_owed', 150)));

  -- B1 the payer edits: 400, split 100.01 / 299.99, new date and title
  perform public.edit_expense(p_expense_id => v_id, p_title => ' Taxi home ',
    p_amount => 400, p_splits => jsonb_build_array(
      jsonb_build_object('user_id', ali, 'amount_owed', 100.01),
      jsonb_build_object('user_id', bilal, 'amount_owed', 299.99)),
    p_category => 'transport', p_split_type => 'custom', p_expense_date => today - 3);
  select count(*) into v_n from public.expenses
   where id = v_id and title = 'Taxi home' and amount = 400 and category = 'transport'
     and split_type = 'custom' and expense_date = today - 3 and edited_at is not null;
  if v_n = 1 then ok := ok + 1; else fails := fails || ' B1'; end if;

  -- B2 the old splits are gone, the new ones are there
  select count(*) into v_n from public.expense_splits
   where expense_id = v_id and ((user_id = ali and amount_owed = 100.01)
                             or (user_id = bilal and amount_owed = 299.99));
  if v_n = 2 and (select count(*) from public.expense_splits where expense_id = v_id) = 2
  then ok := ok + 1; else fails := fails || ' B2'; end if;

  -- B3 the balance follows the edit: Bilal owed Ali 50 + 50 (A2, A3),
  -- Ali now owes Bilal 100.01 for the taxi → Ali owes Bilal exactly 0.01
  select amount into v_amt from public.group_debts(g)
   where debtor_id = ali and creditor_id = bilal;
  if v_amt = 0.01 then ok := ok + 1; else fails := fails || ' B3(' || coalesce(v_amt::text, 'none') || ')'; end if;

  -- B4 splits that don't add up → error, nothing changed
  begin
    perform public.edit_expense(p_expense_id => v_id, p_title => 'Broken',
      p_amount => 400, p_splits => jsonb_build_array(
        jsonb_build_object('user_id', ali, 'amount_owed', 100)),
      p_split_type => 'custom');
    fails := fails || ' B4(saved)';
  exception when others then
    if sqlerrm = 'SPLITS_DONT_ADD_UP'
       and exists (select 1 from public.expenses where id = v_id and title = 'Taxi home')
    then ok := ok + 1; else fails := fails || ' B4(' || sqlerrm || ')'; end if;
  end;

  -- B5 Ali is an admin → may edit Bilal's expense
  perform set_config('request.jwt.claims',
    json_build_object('sub', ali, 'role', 'authenticated')::text, true);
  perform public.edit_expense(p_expense_id => v_id, p_title => 'Taxi (admin)',
    p_amount => 400, p_splits => jsonb_build_array(
      jsonb_build_object('user_id', ali, 'amount_owed', 200),
      jsonb_build_object('user_id', bilal, 'amount_owed', 200)));
  if exists (select 1 from public.expenses where id = v_id and title = 'Taxi (admin)')
  then ok := ok + 1; else fails := fails || ' B5'; end if;

  -- B6 Bilal (not admin) may NOT edit Ali's expense
  select id into v_id from public.expenses
   where group_id = g and paid_by = ali order by created_at limit 1;
  perform set_config('request.jwt.claims',
    json_build_object('sub', bilal, 'role', 'authenticated')::text, true);
  begin
    perform public.edit_expense(p_expense_id => v_id, p_title => 'Hacked',
      p_amount => 100, p_splits => splits);
    fails := fails || ' B6(saved)';
  exception when others then
    if sqlerrm = 'NOT_ALLOWED' then ok := ok + 1; else fails := fails || ' B6(' || sqlerrm || ')'; end if;
  end;

  -- B7 a stranger gets NOT_A_MEMBER
  perform set_config('request.jwt.claims',
    json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
  begin
    perform public.edit_expense(p_expense_id => v_id, p_title => 'Hacked',
      p_amount => 100, p_splits => splits);
    fails := fails || ' B7(saved)';
  exception when others then
    if sqlerrm = 'NOT_A_MEMBER' then ok := ok + 1; else fails := fails || ' B7(' || sqlerrm || ')'; end if;
  end;
  perform set_config('request.jwt.claims',
    json_build_object('sub', ali, 'role', 'authenticated')::text, true);

  -- ── 10c: recurring expenses ───────────────────────────────────────────────
  -- C1 month ends keep their day; leap years; daily / weekly
  if public._next_recur_date(date '2027-01-31', 'monthly', 31) = date '2027-02-28'
     and public._next_recur_date(date '2027-02-28', 'monthly', 31) = date '2027-03-31'
     and public._next_recur_date(date '2027-03-31', 'monthly', 31) = date '2027-04-30'
     and public._next_recur_date(date '2028-01-30', 'monthly', 30) = date '2028-02-29'
     and public._next_recur_date(date '2027-12-15', 'monthly', 15) = date '2028-01-15'
     and public._next_recur_date(date '2027-01-31', 'daily', 31) = date '2027-02-01'
     and public._next_recur_date(date '2027-01-31', 'weekly', 31) = date '2027-02-07'
  then ok := ok + 1; else fails := fails || ' C1'; end if;

  -- C2 a new monthly expense remembers its day, creator, and first due day
  v_id := public.add_expense(p_group_id => g, p_paid_by => ali, p_title => 'Rent',
    p_amount => 100, p_splits => splits, p_is_recurring => true,
    p_recur_every => 'monthly', p_expense_date => today);
  select count(*) into v_n from public.expenses
   where id = v_id and created_by = ali
     and recur_day = extract(day from today)
     and (next_recur_at at time zone 'Asia/Karachi')::date
         = public._next_recur_date(today, 'monthly', extract(day from today)::int);
  if v_n = 1 then ok := ok + 1; else fails := fails || ' C2'; end if;

  -- C3 due 3 days ago (daily) → 4 copies (d-3 .. today), next due tomorrow
  v_id := public.add_expense(p_group_id => g, p_paid_by => ali, p_title => 'Milk',
    p_amount => 100, p_splits => splits, p_is_recurring => true, p_recur_every => 'daily');
  -- From here the job runs like pg_cron (no user)
  perform set_config('request.jwt.claims', '{}', true);
  update public.expenses set next_recur_at = public._recur_at(today - 3) where id = v_id;
  perform public.generate_recurring_expenses();
  select count(*) into v_n from public.expenses e
   where e.recurring_parent_id = v_id and e.expense_date between today - 3 and today
     and e.is_recurring = false and e.amount = 100
     and (select count(*) from public.expense_splits s where s.expense_id = e.id) = 2;
  if v_n = 4 and (select (next_recur_at at time zone 'Asia/Karachi')::date
                    from public.expenses where id = v_id) = today + 1
  then ok := ok + 1; else fails := fails || ' C3(' || v_n || ')'; end if;

  -- C4 running again the same day creates nothing new
  update public.expenses set next_recur_at = public._recur_at(today) where id = v_id;
  perform public.generate_recurring_expenses();
  select count(*) into v_n from public.expenses where recurring_parent_id = v_id;
  if v_n = 4 then ok := ok + 1; else fails := fails || ' C4(' || v_n || ')'; end if;

  -- C5 paused → no copy, the due day stays
  update public.expenses set next_recur_at = public._recur_at(today - 1), recur_paused = true
   where id = v_id;
  perform public.generate_recurring_expenses();
  select count(*) into v_n from public.expenses where recurring_parent_id = v_id;
  if v_n = 4 then ok := ok + 1; else fails := fails || ' C5(' || v_n || ')'; end if;

  -- C6 who may pause / resume / stop: Bilal is not creator, payer or admin
  perform set_config('request.jwt.claims',
    json_build_object('sub', bilal, 'role', 'authenticated')::text, true);
  begin
    perform public.set_recurring_status(v_id, 'stop');
    fails := fails || ' C6(allowed)';
  exception when others then
    if sqlerrm = 'NOT_ALLOWED' then ok := ok + 1; else fails := fails || ' C6(' || sqlerrm || ')'; end if;
  end;

  -- C7 Ali resumes → not paused, next due day is today or later (no back-fill)
  perform set_config('request.jwt.claims',
    json_build_object('sub', ali, 'role', 'authenticated')::text, true);
  perform public.set_recurring_status(v_id, 'resume');
  if exists (select 1 from public.expenses where id = v_id and not recur_paused
               and (next_recur_at at time zone 'Asia/Karachi')::date >= today)
  then ok := ok + 1; else fails := fails || ' C7'; end if;

  -- C8 Ali stops it → a normal expense, the copies stay
  perform public.set_recurring_status(v_id, 'stop');
  if exists (select 1 from public.expenses where id = v_id and not is_recurring
               and next_recur_at is null)
     and (select count(*) from public.expenses where recurring_parent_id = v_id) = 4
  then ok := ok + 1; else fails := fails || ' C8'; end if;

  -- C9 someone left → this copy is skipped, the creator is told, it keeps running
  v_id := public.add_expense(p_group_id => g, p_paid_by => ali, p_title => 'Internet',
    p_amount => 100, p_splits => splits, p_is_recurring => true, p_recur_every => 'weekly');
  perform set_config('request.jwt.claims', '{}', true);
  update public.expenses set next_recur_at = public._recur_at(today) where id = v_id;
  delete from public.group_members where group_id = g and user_id = bilal;
  perform public.generate_recurring_expenses();
  if (select count(*) from public.expenses where recurring_parent_id = v_id) = 0
     and exists (select 1 from public.notifications
                  where user_id = ali and type = 'recurring_skipped'
                    and entity_id = v_id and body like '%Bilal left the group.')
     and exists (select 1 from public.expenses where id = v_id and is_recurring
                   and (next_recur_at at time zone 'Asia/Karachi')::date = today + 7)
  then ok := ok + 1; else fails := fails || ' C9'; end if;
  insert into public.group_members (group_id, user_id, role) values (g, bilal, 'member');

  -- C10 a split that doesn't add up (old data) → skipped + told, not stuck
  update public.expense_splits set amount_owed = 49 where expense_id = v_id and user_id = bilal;
  update public.expenses set next_recur_at = public._recur_at(today) where id = v_id;
  perform public.generate_recurring_expenses();
  if (select count(*) from public.expenses where recurring_parent_id = v_id) = 0
     and exists (select 1 from public.notifications
                  where entity_id = v_id and body like '%please check its split%')
     and exists (select 1 from public.expenses where id = v_id
                   and (next_recur_at at time zone 'Asia/Karachi')::date = today + 7)
  then ok := ok + 1; else fails := fails || ' C10'; end if;

  -- C11 a logged-in user can't run the job
  perform set_config('request.jwt.claims',
    json_build_object('sub', ali, 'role', 'authenticated')::text, true);
  begin
    perform public.generate_recurring_expenses();
    fails := fails || ' C11(ran)';
  exception when others then
    if sqlerrm = 'Not allowed' then ok := ok + 1; else fails := fails || ' C11(' || sqlerrm || ')'; end if;
  end;

  -- ── 10d: group type ───────────────────────────────────────────────────────
  -- D1 the chosen type is saved; old app (no type) and unknown → 'other'
  v_id := public.create_group(p_name => 'P3 trip', p_currency => 'PKR', p_category => 'Trip');
  v_id2 := public.create_group(p_name => 'P3 old app');
  v_id3 := public.create_group(p_name => 'P3 odd', p_category => 'x');
  if (select category from public.groups where id = v_id) = 'trip'
     and (select category from public.groups where id = v_id2) = 'other'
     and (select category from public.groups where id = v_id3) = 'other'
  then ok := ok + 1; else fails := fails || ' D1'; end if;

  -- D2 every group has a known type; only ONE create_group exists
  select count(*) into v_n from pg_proc
   where proname = 'create_group' and pronamespace = 'public'::regnamespace;
  if v_n = 1 and not exists (select 1 from public.groups
       where category not in ('home', 'trip', 'friends', 'office', 'family', 'other'))
  then ok := ok + 1; else fails := fails || ' D2'; end if;

  raise exception 'RESULT: % passed, failed:%', ok, coalesce(nullif(fails, ''), ' none');
end $$;
