-- ============================================================================
-- Splitly — edit an expense (APP_REVIEW.md fix #10, step 10b)
--
--   edit_expense(...)       title, amount, category, date, notes and split,
--                           all in ONE transaction. Only the payer or a
--                           group admin. The payer itself can't change.
--   _check_expense_input()  the checks add_expense and edit_expense share,
--                           so both follow exactly the same money rules
--                           (exact paisa, splits add up, members only).
--   expenses.edited_at      set on every edit; the app shows "edited".
--
-- The app warns before saving when payments were already made after the
-- expense (same warning as delete, Phase 1). Balances come from
-- group_debts(), so they follow the new splits at once.
--
-- Error codes: the add_expense codes, plus EXPENSE_NOT_FOUND, NOT_ALLOWED
--
-- Safe on a database with data and safe to run twice. No REVOKE EXECUTE
-- (see 20261027120000_security_fixes.sql §5); functions guard themselves.
-- ============================================================================


ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS edited_at timestamptz;


-- ── 1. Shared checks ────────────────────────────────────────────────────────
-- Raises the first problem it finds. Who may save, and the payer, are
-- checked by the caller.
CREATE OR REPLACE FUNCTION public._check_expense_input(
  p_group_id uuid,
  p_title text,
  p_amount numeric,
  p_split_type text,
  p_splits jsonb,
  p_expense_date date
)
RETURNS void
LANGUAGE plpgsql STABLE
SET search_path = public
AS $$
declare
  v_count int;
  v_distinct int;
  v_sum numeric;
begin
  if p_title is null or trim(p_title) = '' then
    raise exception 'INVALID_TITLE';
  end if;
  if p_amount is null or p_amount <= 0 or p_amount <> round(p_amount, 2) then
    raise exception 'INVALID_AMOUNT';
  end if;
  if p_split_type is null or p_split_type not in ('equal', 'custom', 'percentage') then
    raise exception 'INVALID_SPLIT_TYPE';
  end if;
  -- Not in the future (1 day of slack for phones in other time zones)
  if p_expense_date is not null
     and (p_expense_date > (now() AT TIME ZONE 'Asia/Karachi')::date + 1
          or p_expense_date < date '2000-01-01') then
    raise exception 'INVALID_DATE';
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
end;
$$;


-- ── 2. add_expense, now using the shared checks ─────────────────────────────
-- Same signature and behaviour as 20261030000000_expense_date.sql.
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
  p_recur_every text DEFAULT NULL,
  p_expense_date date DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_uid uuid := auth.uid();
  v_id uuid := gen_random_uuid();
  v_currency text;
  v_next timestamptz;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_group_member(p_group_id, v_uid) then
    raise exception 'NOT_A_MEMBER';
  end if;
  if p_paid_by is null or not public.is_group_member(p_group_id, p_paid_by) then
    raise exception 'PAYER_NOT_MEMBER';
  end if;
  if coalesce(p_is_recurring, false)
     and coalesce(p_recur_every, '') not in ('daily', 'weekly', 'monthly') then
    raise exception 'INVALID_RECURRENCE';
  end if;
  perform public._check_expense_input(
    p_group_id, p_title, p_amount, p_split_type, p_splits, p_expense_date);

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
    notes, is_recurring, recur_every, next_recur_at, expense_date
  ) values (
    v_id, p_group_id, p_paid_by, trim(p_title), p_amount,
    coalesce(v_currency, 'PKR'), coalesce(p_category, 'other'), p_split_type,
    nullif(trim(coalesce(p_notes, '')), ''),
    coalesce(p_is_recurring, false),
    case when coalesce(p_is_recurring, false) then p_recur_every end,
    v_next,
    coalesce(p_expense_date, (now() AT TIME ZONE 'Asia/Karachi')::date)
  );

  insert into public.expense_splits (expense_id, user_id, amount_owed, is_settled)
  select v_id, s.user_id, s.amount_owed, false
    from jsonb_to_recordset(p_splits) as s(user_id uuid, amount_owed numeric);

  return v_id;
end;
$$;


-- ── 3. edit_expense ─────────────────────────────────────────────────────────
-- p_expense_date NULL = keep the current date. Uses the same per-group lock
-- as the settlement functions, so a payment recorded at the same moment
-- sees either the old or the new splits, never a mix.
CREATE OR REPLACE FUNCTION public.edit_expense(
  p_expense_id uuid,
  p_title text,
  p_amount numeric,
  p_splits jsonb,
  p_category text DEFAULT 'other',
  p_split_type text DEFAULT 'equal',
  p_notes text DEFAULT NULL,
  p_expense_date date DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_uid uuid := auth.uid();
  v_exp public.expenses%rowtype;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_exp from public.expenses where id = p_expense_id;
  if not found then
    raise exception 'EXPENSE_NOT_FOUND';
  end if;
  if not public.is_group_member(v_exp.group_id, v_uid) then
    raise exception 'NOT_A_MEMBER';
  end if;
  if v_uid <> v_exp.paid_by and not public.is_group_admin(v_exp.group_id) then
    raise exception 'NOT_ALLOWED';
  end if;
  if not public.is_group_member(v_exp.group_id, v_exp.paid_by) then
    raise exception 'PAYER_NOT_MEMBER';
  end if;
  perform public._check_expense_input(
    v_exp.group_id, p_title, p_amount, p_split_type, p_splits, p_expense_date);

  perform pg_advisory_xact_lock(hashtext('settle:' || v_exp.group_id::text));
  perform 1 from public.expenses where id = p_expense_id for update;

  update public.expenses
     set title        = trim(p_title),
         amount       = p_amount,
         category     = coalesce(p_category, 'other'),
         split_type   = p_split_type,
         notes        = nullif(trim(coalesce(p_notes, '')), ''),
         expense_date = coalesce(p_expense_date, expense_date),
         edited_at    = now(),
         updated_at   = now()
   where id = p_expense_id;

  delete from public.expense_splits where expense_id = p_expense_id;
  insert into public.expense_splits (expense_id, user_id, amount_owed, is_settled)
  select p_expense_id, s.user_id, s.amount_owed, false
    from jsonb_to_recordset(p_splits) as s(user_id uuid, amount_owed numeric);
end;
$$;
