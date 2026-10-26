-- ============================================================================
-- Splitly — save multi-step writes in ONE transaction (APP_REVIEW.md fix #2)
--
--   create_group(...)   group + creator as admin            (SECURITY INVOKER)
--   add_expense(...)    expense + all its splits, validated (SECURITY DEFINER)
--   delete_expense(id)  expense (splits go with it)         (SECURITY INVOKER)
--   join_group_by_code  already added in 20261027120000_security_fixes.sql
--
-- A Postgres function runs as one transaction: if any part fails, nothing
-- is saved. Because the expense and its splits now commit together, the
-- "notify-new-expense" webhook (pg_net only sends queued requests after the
-- transaction commits) always finds the splits, so the push reaches the
-- right people.
--
-- add_expense is SECURITY DEFINER so direct INSERTs into expenses and
-- expense_splits can be blocked completely: the function is now the only
-- way in, and it checks everything itself.
--
-- Error codes (raised as the exception message, mapped to texts in the app):
--   INVALID_NAME, NOT_A_MEMBER, INVALID_TITLE, INVALID_AMOUNT,
--   PAYER_NOT_MEMBER, INVALID_SPLIT_TYPE, INVALID_RECURRENCE, NO_MEMBERS,
--   DUPLICATE_SPLIT, INVALID_SPLIT_AMOUNT, SPLIT_USER_NOT_MEMBER,
--   SPLITS_DONT_ADD_UP, EXPENSE_NOT_FOUND, NOT_ALLOWED
--
-- No REVOKE EXECUTE anywhere (see 20261027120000_security_fixes.sql §5);
-- every function rejects logged-out callers itself.
--
-- Safe to run on a database with data and safe to run twice: functions are
-- CREATE OR REPLACE, policies DROP IF EXISTS + CREATE, no rows are changed.
-- ============================================================================


-- ── create_group ────────────────────────────────────────────────────────────
-- INVOKER: the caller's own RLS rules already allow both inserts ("Users can
-- create groups" + "Creator can add self as admin"). The id is generated
-- here because the caller can't SELECT the new group back until they are a
-- member (so no INSERT ... RETURNING).
CREATE OR REPLACE FUNCTION public.create_group(
  p_name text,
  p_description text DEFAULT NULL,
  p_currency text DEFAULT 'PKR'
)
RETURNS uuid
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public
AS $$
declare
  v_uid uuid := auth.uid();
  v_id uuid := gen_random_uuid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_name is null or length(trim(p_name)) < 2 then
    raise exception 'INVALID_NAME';
  end if;

  insert into public.groups (id, name, description, currency, created_by)
  values (
    v_id,
    trim(p_name),
    nullif(trim(coalesce(p_description, '')), ''),
    coalesce(nullif(trim(p_currency), ''), 'PKR'),
    v_uid
  );

  insert into public.group_members (group_id, user_id, role)
  values (v_id, v_uid, 'admin');

  return v_id;
end;
$$;


-- ── add_expense ─────────────────────────────────────────────────────────────
-- p_splits: JSON array like [{"user_id": "...", "amount_owed": 33.34}, ...]
-- The currency always comes from the group (the client can't choose it).
-- The next recurring date is calculated here ('1 month' handles month ends:
-- 31 Jan + 1 month = 28/29 Feb).
CREATE OR REPLACE FUNCTION public.add_expense(
  p_group_id uuid,
  p_paid_by uuid,
  p_title text,
  p_amount numeric,
  p_splits jsonb,
  p_category text DEFAULT 'other',
  p_split_type text DEFAULT 'equal',
  p_notes text DEFAULT NULL,
  p_is_recurring boolean DEFAULT false,
  p_recur_every text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_uid uuid := auth.uid();
  v_id uuid := gen_random_uuid();
  v_currency text;
  v_count int;
  v_distinct int;
  v_sum numeric;
  v_next timestamptz;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_group_member(p_group_id, v_uid) then
    raise exception 'NOT_A_MEMBER';
  end if;
  if p_title is null or trim(p_title) = '' then
    raise exception 'INVALID_TITLE';
  end if;
  if p_amount is null or p_amount <= 0 or p_amount <> round(p_amount, 2) then
    raise exception 'INVALID_AMOUNT';
  end if;
  if p_paid_by is null or not public.is_group_member(p_group_id, p_paid_by) then
    raise exception 'PAYER_NOT_MEMBER';
  end if;
  if p_split_type is null or p_split_type not in ('equal', 'custom', 'percentage') then
    raise exception 'INVALID_SPLIT_TYPE';
  end if;
  if coalesce(p_is_recurring, false)
     and coalesce(p_recur_every, '') not in ('daily', 'weekly', 'monthly') then
    raise exception 'INVALID_RECURRENCE';
  end if;

  -- At least one person must be in the split
  if p_splits is null or jsonb_typeof(p_splits) <> 'array'
     or jsonb_array_length(p_splits) = 0 then
    raise exception 'NO_MEMBERS';
  end if;

  if exists (
    select 1 from jsonb_to_recordset(p_splits) as s(user_id uuid, amount_owed numeric)
     where s.user_id is null or s.amount_owed is null or s.amount_owed < 0
        or s.amount_owed <> round(s.amount_owed, 2)
  ) then
    raise exception 'INVALID_SPLIT_AMOUNT';
  end if;

  select count(*), count(distinct s.user_id), sum(s.amount_owed)
    into v_count, v_distinct, v_sum
    from jsonb_to_recordset(p_splits) as s(user_id uuid, amount_owed numeric);
  if v_count <> v_distinct then
    raise exception 'DUPLICATE_SPLIT';
  end if;

  -- Every person in the split must be a member of this group
  if exists (
    select 1 from jsonb_to_recordset(p_splits) as s(user_id uuid, amount_owed numeric)
     where not public.is_group_member(p_group_id, s.user_id)
  ) then
    raise exception 'SPLIT_USER_NOT_MEMBER';
  end if;

  -- The splits must add up to the amount EXACTLY (to the paisa)
  if v_sum <> p_amount then
    raise exception 'SPLITS_DONT_ADD_UP';
  end if;

  select currency into v_currency from public.groups where id = p_group_id;

  if coalesce(p_is_recurring, false) then
    v_next := now() + case p_recur_every
      when 'daily'  then interval '1 day'
      when 'weekly' then interval '7 days'
      else               interval '1 month'
    end;
  end if;

  insert into public.expenses (
    id, group_id, paid_by, title, amount, currency, category, split_type,
    notes, is_recurring, recur_every, next_recur_at
  ) values (
    v_id, p_group_id, p_paid_by, trim(p_title), p_amount,
    coalesce(v_currency, 'PKR'), coalesce(p_category, 'other'), p_split_type,
    nullif(trim(coalesce(p_notes, '')), ''),
    coalesce(p_is_recurring, false),
    case when coalesce(p_is_recurring, false) then p_recur_every end,
    v_next
  );

  insert into public.expense_splits (expense_id, user_id, amount_owed, is_settled)
  select v_id, s.user_id, s.amount_owed, false
    from jsonb_to_recordset(p_splits) as s(user_id uuid, amount_owed numeric);

  return v_id;
end;
$$;


-- ── delete_expense ──────────────────────────────────────────────────────────
-- INVOKER: same rule as before (only the payer), now with a clear error
-- instead of silently deleting nothing. The splits are removed by
-- ON DELETE CASCADE in the same statement.
CREATE OR REPLACE FUNCTION public.delete_expense(p_expense_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public
AS $$
declare
  v_uid uuid := auth.uid();
  v_paid_by uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select paid_by into v_paid_by from public.expenses where id = p_expense_id;
  if not found then
    raise exception 'EXPENSE_NOT_FOUND';
  end if;
  if v_paid_by <> v_uid then
    raise exception 'NOT_ALLOWED';
  end if;

  delete from public.expenses where id = p_expense_id;
end;
$$;


-- ── Block direct inserts: add_expense() is the only way in ──────────────────
DROP POLICY IF EXISTS "Members can insert expenses" ON public.expenses;
DROP POLICY IF EXISTS "Members can insert splits" ON public.expense_splits;
REVOKE INSERT ON public.expenses FROM anon, authenticated;
REVOKE INSERT ON public.expense_splits FROM anon, authenticated;


-- ── Storage: allow deleting your own files ──────────────────────────────────
-- Needed so the app can remove an uploaded file when saving the database
-- row fails, and remove an old avatar / group photo after replacing it.

DROP POLICY IF EXISTS "Users can delete own chat attachments" ON storage.objects;
CREATE POLICY "Users can delete own chat attachments" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'chat-attachments' AND owner_id = auth.uid()::text);

DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
CREATE POLICY "Users can delete own avatar" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Creator can delete group photo" ON storage.objects;
CREATE POLICY "Creator can delete group photo" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'group-photos'
    AND (storage.foldername(name))[1] IN
        (SELECT id::text FROM public.groups WHERE created_by = auth.uid())
  );
