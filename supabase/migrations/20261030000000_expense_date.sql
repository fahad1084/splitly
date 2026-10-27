-- ============================================================================
-- Splitly — expense date (APP_REVIEW.md fix #10, step 10a)
--
-- expenses.expense_date: the day the money was spent, picked by the user
-- (default today). Lists, reports and exports use it instead of created_at.
-- created_at stays the moment the expense was saved (the "payments made
-- after this expense" warning and the debt reminders keep using it).
--
-- add_expense gets an optional p_expense_date. Old app versions don't send
-- it and get today's date, so they keep working.
--
-- Existing rows: expense_date = the day of created_at in Pakistan time.
--
-- Error codes: INVALID_DATE (plus the add_expense codes)
--
-- Safe on a database with data and safe to run twice.
-- ============================================================================


-- ── 1. The column, filled for existing rows ─────────────────────────────────
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS expense_date date;

UPDATE public.expenses
   SET expense_date = (created_at AT TIME ZONE 'Asia/Karachi')::date
 WHERE expense_date IS NULL;

ALTER TABLE public.expenses
  ALTER COLUMN expense_date SET DEFAULT ((now() AT TIME ZONE 'Asia/Karachi')::date),
  ALTER COLUMN expense_date SET NOT NULL;

-- The app lists a group's expenses newest date first
CREATE INDEX IF NOT EXISTS expenses_group_date_idx
  ON public.expenses (group_id, expense_date DESC, created_at DESC);


-- ── 2. add_expense with an optional date ────────────────────────────────────
-- Same body as 20261027130000_transactions.sql, plus p_expense_date.
-- The old 10-argument version is dropped first, otherwise both would exist
-- and calls without a date would be ambiguous.
DROP FUNCTION IF EXISTS public.add_expense(
  uuid, uuid, text, numeric, jsonb, text, text, text, boolean, text);

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
  v_count int;
  v_distinct int;
  v_sum numeric;
  v_next timestamptz;
  v_today date := (now() AT TIME ZONE 'Asia/Karachi')::date;
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
  -- Not in the future (1 day of slack for phones in other time zones)
  if p_expense_date is not null
     and (p_expense_date > v_today + 1 or p_expense_date < date '2000-01-01') then
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
    coalesce(p_expense_date, v_today)
  );

  insert into public.expense_splits (expense_id, user_id, amount_owed, is_settled)
  select v_id, s.user_id, s.amount_owed, false
    from jsonb_to_recordset(p_splits) as s(user_id uuid, amount_owed numeric);

  return v_id;
end;
$$;
