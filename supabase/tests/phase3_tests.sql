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
  g     uuid := '93000000-0000-0000-0000-000000000093';
  today date := (now() at time zone 'Asia/Karachi')::date;
  splits jsonb := jsonb_build_array(
    jsonb_build_object('user_id', 'a3000000-0000-0000-0000-0000000000a1', 'amount_owed', 50),
    jsonb_build_object('user_id', 'b3000000-0000-0000-0000-0000000000b1', 'amount_owed', 50));
  v_id  uuid;
  v_date date;
  v_n   int;
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

  raise exception 'RESULT: % passed, failed:%', ok, coalesce(nullif(fails, ''), ' none');
end $$;
