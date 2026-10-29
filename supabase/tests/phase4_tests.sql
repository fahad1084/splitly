-- ============================================================================
-- Phase 4 tests (archive rights, edit history + notifications, admin delete)
--
-- SAFE ON splitly-test: everything runs in ONE block that always ends with
-- an error, which undoes every change. The error text IS the result:
--     RESULT: 14 passed, failed: none
--
--   supabase db query --linked -f supabase/tests/phase4_tests.sql
-- or on the local database:
--   supabase db query --local -f supabase/tests/phase4_tests.sql
--
-- The delete-vs-confirm race needs two connections at once:
-- tests/delete_confirm_race_test.sh (local only).
-- ============================================================================
do $$
declare
  ali   uuid := 'a4000000-0000-0000-0000-0000000000a1'; -- creator (admin)
  bilal uuid := 'b4000000-0000-0000-0000-0000000000b1'; -- member
  chand uuid := 'c4000000-0000-0000-0000-0000000000c1'; -- member, later admin
  g     uuid := '95000000-0000-0000-0000-000000000095';
  v_id  uuid;
  v_n   int;
  v_txt text;
  ok    int := 0;
  fails text := '';
begin
  insert into auth.users (id, email, aud, role) values
    (ali, 'p4-ali@test.local', 'authenticated', 'authenticated'),
    (bilal, 'p4-bilal@test.local', 'authenticated', 'authenticated'),
    (chand, 'p4-chand@test.local', 'authenticated', 'authenticated');
  insert into public.profiles (id, full_name) values (ali, 'Ali'), (bilal, 'Bilal'), (chand, 'Chand')
    on conflict (id) do update set full_name = excluded.full_name;
  update public.profiles set notify_expenses = true where id in (ali, bilal, chand);
  insert into public.groups (id, name, currency, created_by) values (g, 'P4 test', 'PKR', ali);
  insert into public.group_members (group_id, user_id, role) values
    (g, ali, 'admin'), (g, bilal, 'member'), (g, chand, 'member');

  -- ── Archive ───────────────────────────────────────────────────────────────
  -- R1 a normal member can't archive (real error, group unchanged)
  perform set_config('request.jwt.claims', json_build_object('sub', bilal, 'role', 'authenticated')::text, true);
  begin
    perform public.set_group_archived(g, true);
    fails := fails || ' R1(allowed)';
  exception when others then
    if sqlerrm = 'NOT_ALLOWED' and not (select is_archived from public.groups where id = g)
    then ok := ok + 1; else fails := fails || ' R1(' || sqlerrm || ')'; end if;
  end;

  -- R2 an admin who is not the creator can archive
  update public.group_members set role = 'admin' where group_id = g and user_id = chand;
  perform set_config('request.jwt.claims', json_build_object('sub', chand, 'role', 'authenticated')::text, true);
  perform public.set_group_archived(g, true);
  if (select is_archived from public.groups where id = g) then ok := ok + 1; else fails := fails || ' R2'; end if;

  -- R3 the creator can unarchive
  perform set_config('request.jwt.claims', json_build_object('sub', ali, 'role', 'authenticated')::text, true);
  perform public.set_group_archived(g, false);
  if not (select is_archived from public.groups where id = g) then ok := ok + 1; else fails := fails || ' R3'; end if;

  -- R4 an outsider gets NOT_A_MEMBER
  perform set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
  begin
    perform public.set_group_archived(g, true);
    fails := fails || ' R4(allowed)';
  exception when others then
    if sqlerrm = 'NOT_A_MEMBER' then ok := ok + 1; else fails := fails || ' R4(' || sqlerrm || ')'; end if;
  end;
  update public.group_members set role = 'member' where group_id = g and user_id = chand;

  -- ── Edit history + notifications ──────────────────────────────────────────
  -- Bilal pays 300 split Ali 150 / Bilal 150
  perform set_config('request.jwt.claims', json_build_object('sub', bilal, 'role', 'authenticated')::text, true);
  v_id := public.add_expense(p_group_id => g, p_paid_by => bilal, p_title => 'Dinner',
    p_amount => 300, p_splits => jsonb_build_array(
      jsonb_build_object('user_id', ali, 'amount_owed', 150),
      jsonb_build_object('user_id', bilal, 'amount_owed', 150)));

  -- H1 an edit that changes nothing is not saved and notifies nobody
  perform public.edit_expense(p_expense_id => v_id, p_title => 'Dinner', p_amount => 300,
    p_splits => jsonb_build_array(
      jsonb_build_object('user_id', ali, 'amount_owed', 150),
      jsonb_build_object('user_id', bilal, 'amount_owed', 150)));
  if not exists (select 1 from public.expense_edits where expense_id = v_id)
     and (select edited_at from public.expenses where id = v_id) is null
  then ok := ok + 1; else fails := fails || ' H1'; end if;

  -- Bilal changes it to 400, split Ali 100 / Bilal 100 / Chand 200
  perform public.edit_expense(p_expense_id => v_id, p_title => 'Dinner', p_amount => 400,
    p_splits => jsonb_build_array(
      jsonb_build_object('user_id', ali, 'amount_owed', 100),
      jsonb_build_object('user_id', bilal, 'amount_owed', 100),
      jsonb_build_object('user_id', chand, 'amount_owed', 200)),
    p_split_type => 'custom');

  -- H2 one history row: who, amount 300 → 400, the splits before/after
  select count(*) into v_n from public.expense_edits
   where expense_id = v_id and edited_by = bilal
     and (changes -> 'amount' ->> 'from')::numeric = 300
     and (changes -> 'amount' ->> 'to')::numeric = 400
     and (changes -> 'splits' -> 'from' ->> ali::text)::numeric = 150
     and (changes -> 'splits' -> 'to' ->> chand::text)::numeric = 200
     and not changes ? 'title';
  if v_n = 1 then ok := ok + 1; else fails := fails || ' H2'; end if;

  -- H3 Ali and Chand are told (with their own share), Bilal (the editor) is not
  select body into v_txt from public.notifications
   where user_id = ali and type = 'expense_edited' and entity_id = v_id;
  if v_txt like 'Bilal changed "Dinner": PKR 300.00 → PKR 400.00.%Your share: PKR 150.00 → PKR 100.00.'
     and exists (select 1 from public.notifications where user_id = chand
                  and type = 'expense_edited' and body like '%Your share: PKR 0.00 → PKR 200.00.')
     and not exists (select 1 from public.notifications where user_id = bilal and type = 'expense_edited')
  then ok := ok + 1; else fails := fails || ' H3(' || coalesce(v_txt, 'none') || ')'; end if;

  -- H4 someone who muted expenses gets no notification
  update public.profiles set notify_expenses = false where id = chand;
  perform public.edit_expense(p_expense_id => v_id, p_title => 'Dinner out', p_amount => 400,
    p_splits => jsonb_build_array(
      jsonb_build_object('user_id', ali, 'amount_owed', 100),
      jsonb_build_object('user_id', bilal, 'amount_owed', 100),
      jsonb_build_object('user_id', chand, 'amount_owed', 200)),
    p_split_type => 'custom');
  select count(*) into v_n from public.notifications where user_id = chand and type = 'expense_edited';
  if v_n = 1 and (select count(*) from public.notifications
                   where user_id = ali and type = 'expense_edited') = 2
  then ok := ok + 1; else fails := fails || ' H4'; end if;
  update public.profiles set notify_expenses = true where id = chand;

  -- H5 group members can read the history, outsiders can't
  perform set_config('request.jwt.claims', json_build_object('sub', chand, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into v_n from public.expense_edits where expense_id = v_id;
  perform set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
  if v_n = 2 and (select count(*) from public.expense_edits where expense_id = v_id) = 0
  then ok := ok + 1; else fails := fails || ' H5(' || v_n || ')'; end if;

  -- H6 nobody can write the history directly
  perform set_config('request.jwt.claims', json_build_object('sub', bilal, 'role', 'authenticated')::text, true);
  begin
    insert into public.expense_edits (expense_id, group_id, edited_by, changes)
    values (v_id, g, bilal, '{}');
    fails := fails || ' H6(inserted)';
  exception when others then
    ok := ok + 1;
  end;
  execute 'reset role';

  -- ── Delete: payer or admin ────────────────────────────────────────────────
  -- D1 Chand (normal member, not the payer) can't delete Bilal's expense
  perform set_config('request.jwt.claims', json_build_object('sub', chand, 'role', 'authenticated')::text, true);
  begin
    perform public.delete_expense(v_id);
    fails := fails || ' D1(deleted)';
  exception when others then
    if sqlerrm = 'NOT_ALLOWED' then ok := ok + 1; else fails := fails || ' D1(' || sqlerrm || ')'; end if;
  end;

  -- D2 an outsider gets EXPENSE_NOT_FOUND (as before: they can't see it)
  perform set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
  begin
    perform public.delete_expense(v_id);
    fails := fails || ' D2(deleted)';
  exception when others then
    if sqlerrm = 'EXPENSE_NOT_FOUND' then ok := ok + 1; else fails := fails || ' D2(' || sqlerrm || ')'; end if;
  end;

  -- D3 Ali (admin, not the payer) can delete it; its history goes with it
  perform set_config('request.jwt.claims', json_build_object('sub', ali, 'role', 'authenticated')::text, true);
  perform public.delete_expense(v_id);
  if not exists (select 1 from public.expenses where id = v_id)
     and not exists (select 1 from public.expense_edits where expense_id = v_id)
  then ok := ok + 1; else fails := fails || ' D3'; end if;

  -- D4 delete_expense takes the money lock (the race itself: the .sh test)
  if (select prosrc from pg_proc where proname = 'delete_expense'
       and pronamespace = 'public'::regnamespace) like '%pg_advisory_xact_lock%'
  then ok := ok + 1; else fails := fails || ' D4'; end if;

  raise exception 'RESULT: % passed, failed:%', ok, coalesce(nullif(fails, ''), ' none');
end $$;
