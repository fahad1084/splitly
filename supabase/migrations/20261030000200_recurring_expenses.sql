-- ============================================================================
-- Splitly — recurring expenses that work (APP_REVIEW.md fix #10, step 10c)
--
-- The daily pg_cron job 'generate-recurring-expenses' (07:00 PKT, see
-- setup/webhooks_and_cron.sql) already calls generate_recurring_expenses().
-- The job stays the same; this migration replaces the function:
--
--   * Month ends: a monthly expense keeps its day. 31 Jan → 28/29 Feb →
--     31 Mar → 30 Apr (the old code drifted to the 28th for good).
--   * Each copy is made in its own sub-transaction with the add_expense
--     checks (_check_expense_input). One bad expense never stops the rest.
--     On an unexpected error it stops there and tries again the next day.
--   * Someone left: when the payer or a person in the split is no longer
--     in the group, that copy is SKIPPED (the next ones still run) and the
--     creator gets an in-app notification + push ('recurring_skipped').
--   * Missed days (cron down) are caught up, max 31 copies per run each.
--   * The copy's expense_date is the day it was due; recurring_parent_id
--     points back to the recurring expense. A unique index makes sure the
--     same day is never created twice.
--   * Paused expenses are skipped; archived groups are skipped quietly.
--
--   set_recurring_status(id, 'pause' | 'resume' | 'stop')
--     creator, payer or group admin. Resume does not create the copies
--     missed while paused; it continues from the next due day.
--
-- New columns on expenses: created_by, recur_paused, recur_day,
-- recurring_parent_id. Existing rows: created_by = paid_by; recur_day =
-- the day of the month of the expense date.
--
-- next_recur_at now always means "the due day at 00:00 Pakistan time".
--
-- Error codes: EXPENSE_NOT_FOUND, NOT_A_MEMBER, NOT_ALLOWED, NOT_RECURRING,
--   INVALID_ACTION (plus the add_expense codes)
--
-- Safe on a database with data and safe to run twice. No REVOKE EXECUTE
-- (see 20261027120000_security_fixes.sql §5); functions guard themselves.
-- ============================================================================


-- ── 1. Columns ──────────────────────────────────────────────────────────────
ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS recur_paused boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS recur_day smallint,
  ADD COLUMN IF NOT EXISTS recurring_parent_id uuid
    REFERENCES public.expenses(id) ON DELETE SET NULL;

UPDATE public.expenses SET created_by = paid_by WHERE created_by IS NULL;
UPDATE public.expenses
   SET recur_day = extract(day FROM expense_date)::smallint
 WHERE is_recurring AND recur_day IS NULL;

ALTER TABLE public.expenses DROP CONSTRAINT IF EXISTS expenses_recur_day_check;
ALTER TABLE public.expenses
  ADD CONSTRAINT expenses_recur_day_check CHECK (recur_day BETWEEN 1 AND 31);

-- One copy per recurring expense per day, even if the job runs twice
CREATE UNIQUE INDEX IF NOT EXISTS expenses_recurring_copy_once
  ON public.expenses (recurring_parent_id, expense_date)
  WHERE recurring_parent_id IS NOT NULL;

-- The daily job looks for due recurring expenses
CREATE INDEX IF NOT EXISTS expenses_recurring_due_idx
  ON public.expenses (next_recur_at)
  WHERE is_recurring AND NOT recur_paused;


-- ── 2. The next due day ─────────────────────────────────────────────────────
-- Monthly: the same day next month, or that month's last day when it is
-- shorter (p_day 31: Jan 31 → Feb 28 → Mar 31).
CREATE OR REPLACE FUNCTION public._next_recur_date(
  p_from date, p_every text, p_day int)
RETURNS date
LANGUAGE plpgsql IMMUTABLE
AS $$
declare
  v_month date;
  v_last date;
begin
  if p_every = 'daily' then
    return p_from + 1;
  elsif p_every = 'weekly' then
    return p_from + 7;
  end if;
  v_month := (date_trunc('month', p_from) + interval '1 month')::date;
  v_last := (v_month + interval '1 month' - interval '1 day')::date;
  return least(
    v_month + (least(greatest(coalesce(p_day, extract(day from p_from)::int), 1), 31) - 1),
    v_last);
end;
$$;

-- A due day as the timestamptz stored in next_recur_at (00:00 PKT)
CREATE OR REPLACE FUNCTION public._recur_at(p_day date)
RETURNS timestamptz
LANGUAGE sql IMMUTABLE
AS $$ select (p_day::timestamp AT TIME ZONE 'Asia/Karachi') $$;


-- ── 3. add_expense: remembers the creator and the day of the month ──────────
-- Same signature and checks as 20261030000100_edit_expense.sql. The first
-- copy is due one period after the expense date.
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
  v_date date := coalesce(p_expense_date, (now() AT TIME ZONE 'Asia/Karachi')::date);
  v_recurring boolean := coalesce(p_is_recurring, false);
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
  if v_recurring
     and coalesce(p_recur_every, '') not in ('daily', 'weekly', 'monthly') then
    raise exception 'INVALID_RECURRENCE';
  end if;
  perform public._check_expense_input(
    p_group_id, p_title, p_amount, p_split_type, p_splits, p_expense_date);

  select currency into v_currency from public.groups where id = p_group_id;

  insert into public.expenses (
    id, group_id, paid_by, title, amount, currency, category, split_type,
    notes, is_recurring, recur_every, next_recur_at, recur_day,
    expense_date, created_by
  ) values (
    v_id, p_group_id, p_paid_by, trim(p_title), p_amount,
    coalesce(v_currency, 'PKR'), coalesce(p_category, 'other'), p_split_type,
    nullif(trim(coalesce(p_notes, '')), ''),
    v_recurring,
    case when v_recurring then p_recur_every end,
    case when v_recurring then public._recur_at(
      public._next_recur_date(v_date, p_recur_every, extract(day from v_date)::int)) end,
    case when v_recurring then extract(day from v_date)::smallint end,
    v_date,
    v_uid
  );

  insert into public.expense_splits (expense_id, user_id, amount_owed, is_settled)
  select v_id, s.user_id, s.amount_owed, false
    from jsonb_to_recordset(p_splits) as s(user_id uuid, amount_owed numeric);

  return v_id;
end;
$$;


-- ── 4. The daily job ────────────────────────────────────────────────────────
-- Only pg_cron / the SQL editor / the service role may run it (an API call
-- with a user JWT is refused).
CREATE OR REPLACE FUNCTION public.generate_recurring_expenses()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
declare
  rec record;
  v_today date := (now() AT TIME ZONE 'Asia/Karachi')::date;
  v_due date;
  v_made int;
  v_splits jsonb;
  v_left text;
  v_new uuid;
  v_group_name text;
  v_archived boolean;
begin
  if coalesce(auth.role(), '') in ('anon', 'authenticated') then
    raise exception 'Not allowed';
  end if;

  for rec in
    select * from public.expenses
     where is_recurring and not recur_paused
       and next_recur_at is not null
       and (next_recur_at AT TIME ZONE 'Asia/Karachi')::date <= v_today
     order by next_recur_at
     for update skip locked
  loop
    v_due := (rec.next_recur_at AT TIME ZONE 'Asia/Karachi')::date;
    v_made := 0;
    select name, coalesce(is_archived, false) into v_group_name, v_archived
      from public.groups where id = rec.group_id;

    select coalesce(jsonb_agg(jsonb_build_object(
             'user_id', s.user_id, 'amount_owed', s.amount_owed)), '[]'::jsonb)
      into v_splits
      from public.expense_splits s where s.expense_id = rec.id;

    while v_due <= v_today and v_made < 31 loop
      begin
        -- Who in this expense is no longer in the group?
        select string_agg(coalesce(p.full_name, 'Someone'), ', ' order by p.full_name)
          into v_left
          from (select rec.paid_by as uid
                union
                select s.user_id from public.expense_splits s where s.expense_id = rec.id) x
          left join public.profiles p on p.id = x.uid
         where not public.is_group_member(rec.group_id, x.uid);

        if v_archived then
          null; -- archived group: skip quietly
        elsif v_left is not null then
          -- Skip this copy and tell the creator (the push goes out through
          -- the notifications_push trigger below)
          insert into public.notifications (user_id, type, title, body, group_id, entity_id)
          values (coalesce(rec.created_by, rec.paid_by), 'recurring_skipped',
                  coalesce(v_group_name, 'Splitly'),
                  '"' || rec.title || '" was not added for '
                    || to_char(v_due, 'DD Mon YYYY') || ': '
                    || v_left || ' left the group.',
                  rec.group_id, rec.id);
        else
          -- Same rules as add_expense. A recurring expense that breaks them
          -- (e.g. old data whose split doesn't add up) is skipped like above.
          begin
            perform public._check_expense_input(
              rec.group_id, rec.title, rec.amount,
              coalesce(rec.split_type, 'equal'), v_splits, null);
          exception when raise_exception then
            insert into public.notifications (user_id, type, title, body, group_id, entity_id)
            values (coalesce(rec.created_by, rec.paid_by), 'recurring_skipped',
                    coalesce(v_group_name, 'Splitly'),
                    '"' || rec.title || '" was not added for '
                      || to_char(v_due, 'DD Mon YYYY')
                      || ': please check its split and edit it.',
                    rec.group_id, rec.id);
            v_splits := null; -- marks "skipped" for the insert below
          end;
        end if;

        if not v_archived and v_left is null and v_splits is not null then
          v_new := gen_random_uuid();
          insert into public.expenses (
            id, group_id, paid_by, title, amount, currency, category,
            split_type, notes, is_recurring, expense_date, created_by,
            recurring_parent_id
          ) values (
            v_new, rec.group_id, rec.paid_by, rec.title, rec.amount,
            rec.currency, rec.category, coalesce(rec.split_type, 'equal'), rec.notes,
            false, v_due, rec.created_by, rec.id
          )
          on conflict (recurring_parent_id, expense_date)
            where recurring_parent_id is not null
          do nothing;

          if found then
            insert into public.expense_splits (expense_id, user_id, amount_owed, is_settled)
            select v_new, s.user_id, s.amount_owed, false
              from public.expense_splits s where s.expense_id = rec.id;
          end if;
        end if;
      exception when others then
        -- Unexpected problem: keep this day due, try again tomorrow
        raise warning 'recurring expense % not created for %: %', rec.id, v_due, sqlerrm;
        exit;
      end;

      v_due := public._next_recur_date(
        v_due, rec.recur_every,
        coalesce(rec.recur_day, extract(day from rec.expense_date)::int));
      v_made := v_made + 1;
    end loop;

    update public.expenses
       set next_recur_at = public._recur_at(v_due)
     where id = rec.id;
  end loop;
end;
$$;


-- ── 5. Pause / resume / stop ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_recurring_status(
  p_expense_id uuid, p_action text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_uid uuid := auth.uid();
  v_exp public.expenses%rowtype;
  v_today date := (now() AT TIME ZONE 'Asia/Karachi')::date;
  v_due date;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_action is null or p_action not in ('pause', 'resume', 'stop') then
    raise exception 'INVALID_ACTION';
  end if;

  select * into v_exp from public.expenses where id = p_expense_id for update;
  if not found then
    raise exception 'EXPENSE_NOT_FOUND';
  end if;
  if not public.is_group_member(v_exp.group_id, v_uid) then
    raise exception 'NOT_A_MEMBER';
  end if;
  if v_uid is distinct from coalesce(v_exp.created_by, v_exp.paid_by)
     and v_uid <> v_exp.paid_by
     and not public.is_group_admin(v_exp.group_id) then
    raise exception 'NOT_ALLOWED';
  end if;
  if not v_exp.is_recurring then
    raise exception 'NOT_RECURRING';
  end if;

  if p_action = 'pause' then
    update public.expenses set recur_paused = true, updated_at = now()
     where id = p_expense_id;
  elsif p_action = 'resume' then
    -- Continue from the next due day that hasn't passed yet
    v_due := coalesce((v_exp.next_recur_at AT TIME ZONE 'Asia/Karachi')::date, v_today);
    while v_due < v_today loop
      v_due := public._next_recur_date(
        v_due, v_exp.recur_every,
        coalesce(v_exp.recur_day, extract(day from v_exp.expense_date)::int));
    end loop;
    update public.expenses
       set recur_paused = false, next_recur_at = public._recur_at(v_due),
           updated_at = now()
     where id = p_expense_id;
  else
    -- Stop for good: it becomes a normal expense (the copies stay)
    update public.expenses
       set is_recurring = false, recur_paused = false, next_recur_at = null,
           updated_at = now()
     where id = p_expense_id;
  end if;
end;
$$;


-- ── 6. Push for 'recurring_skipped' notifications ───────────────────────────
-- Same pattern as 20261029000000_settlement_update_push.sql: reads the
-- function URL and secret from Vault, does nothing without them, never
-- makes the insert fail. The Edge Function sends ONLY the push (the
-- in-app notification is this row).
CREATE OR REPLACE FUNCTION public._push_notification_row()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'push_function_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'push_webhook_secret';
  if v_url is null or v_secret is null then
    return new; -- not set up on this project
  end if;

  perform net.http_post(
    url := v_url,
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', TG_TABLE_NAME,
      'schema', TG_TABLE_SCHEMA,
      'record', to_jsonb(new),
      'old_record', null
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    timeout_milliseconds := 5000
  );
  return new;
exception when others then
  raise warning 'notification push not queued: %', sqlerrm;
  return new;
end;
$$;

DROP TRIGGER IF EXISTS notifications_push ON public.notifications;
CREATE TRIGGER notifications_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  WHEN (new.type = 'recurring_skipped')
  EXECUTE FUNCTION public._push_notification_row();
