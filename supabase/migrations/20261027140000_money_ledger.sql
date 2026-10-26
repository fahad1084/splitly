-- ============================================================================
-- Splitly — correct money math: settlements become a ledger
-- (APP_REVIEW.md fix #1, step 5a)
--
-- Balance between two people in a group =
--     what they owe each other from expense splits
--   − CONFIRMED settlements between them
-- netted into one amount per pair. `expense_splits.is_settled` is no longer
-- used for money (the column stays, untouched, for old data).
--
-- Settlement flow:
--   record_settlement  debtor records "I paid" → status 'pending'
--                      receiver records "I got paid" → 'confirmed' at once
--                      partial amounts allowed, never more than is owed
--   confirm_settlement only the receiver: 'pending' → 'confirmed'
--   cancel_settlement  either side: 'pending' → 'cancelled'
--   leave_group        blocked while you still owe or are owed money
--
-- One source of truth for the math: group_debts(). Everything else (the
-- app via get_my_debts, the reminder Edge Function via
-- debts_for_reminders, leave_group, record/confirm) uses it.
--
-- Existing data (runs ONCE, the first time this migration is applied):
--   * old settlements rows  → status 'legacy' (kept as history, NOT counted:
--     the old app ignored their amount and flipped is_settled instead)
--   * already-settled splits → ONE 'migrated' confirmed settlement per
--     group + debtor + creditor, so every balance stays exactly what users
--     see today
--   * the push webhook on settlements is switched off during this copy, so
--     nobody gets notifications for the migrated rows
--
-- Error codes (exception message): NOT_A_MEMBER, NOT_ALLOWED,
--   INVALID_AMOUNT, NO_DEBT, AMOUNT_TOO_HIGH, NOT_FOUND, NOT_PENDING,
--   HAS_UNSETTLED_DEBTS
--
-- Safe on a database with data and safe to run twice. No REVOKE EXECUTE
-- (see 20261027120000_security_fixes.sql §5); functions guard themselves.
-- ============================================================================


-- ── 1. New settlement columns + one-time conversion of existing data ────────
DO $$
DECLARE
  v_has_webhook boolean;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'settlements'
       AND column_name = 'status'
  ) THEN
    ALTER TABLE public.settlements
      ADD COLUMN status text NOT NULL DEFAULT 'confirmed',
      ADD COLUMN kind text NOT NULL DEFAULT 'payment',
      ADD COLUMN created_by uuid REFERENCES public.profiles(id),
      ADD COLUMN confirmed_at timestamptz,
      ADD COLUMN cancelled_at timestamptz,
      ADD COLUMN cancelled_by uuid REFERENCES public.profiles(id);

    -- Old rows: history only (their effect is in the migrated rows below)
    UPDATE public.settlements
       SET status = 'legacy', confirmed_at = created_at, created_by = paid_by;

    -- No push notifications for the rows we are about to copy in
    SELECT EXISTS (
      SELECT 1 FROM pg_trigger
       WHERE tgrelid = 'public.settlements'::regclass
         AND tgname = 'notify-new-settlement' AND NOT tgisinternal
    ) INTO v_has_webhook;
    IF v_has_webhook THEN
      ALTER TABLE public.settlements DISABLE TRIGGER "notify-new-settlement";
    END IF;

    INSERT INTO public.settlements
      (group_id, paid_by, paid_to, amount, currency, status, kind,
       created_by, created_at, confirmed_at)
    SELECT e.group_id, s.user_id, e.paid_by, sum(s.amount_owed),
           max(g.currency), 'confirmed', 'migrated',
           s.user_id,
           coalesce(max(s.settled_at), now()), coalesce(max(s.settled_at), now())
      FROM public.expense_splits s
      JOIN public.expenses e ON e.id = s.expense_id
      JOIN public.groups g ON g.id = e.group_id
     WHERE s.is_settled = true
       AND s.user_id <> e.paid_by
     GROUP BY e.group_id, s.user_id, e.paid_by
    HAVING sum(s.amount_owed) > 0;

    IF v_has_webhook THEN
      ALTER TABLE public.settlements ENABLE TRIGGER "notify-new-settlement";
    END IF;
  END IF;
END $$;

-- New rows are pending unless the RPC says otherwise
ALTER TABLE public.settlements ALTER COLUMN status SET DEFAULT 'pending';

ALTER TABLE public.settlements DROP CONSTRAINT IF EXISTS settlements_status_check;
ALTER TABLE public.settlements
  ADD CONSTRAINT settlements_status_check
  CHECK (status IN ('pending', 'confirmed', 'cancelled', 'legacy'));

ALTER TABLE public.settlements DROP CONSTRAINT IF EXISTS settlements_kind_check;
ALTER TABLE public.settlements
  ADD CONSTRAINT settlements_kind_check CHECK (kind IN ('payment', 'migrated'));

CREATE INDEX IF NOT EXISTS settlements_group_status_idx
  ON public.settlements (group_id, status);


-- ── 2. THE balance math (single source of truth) ────────────────────────────
-- One row per pair of people who still owe each other something:
-- debtor_id owes creditor_id `amount`. Exact numeric math, no rounding.
-- Allowed for: members of the group, the service role (Edge Functions),
-- and internal callers with no JWT (other functions, pg_cron, SQL editor).
CREATE OR REPLACE FUNCTION public.group_debts(p_group_id uuid)
RETURNS TABLE (debtor_id uuid, creditor_id uuid, amount numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
begin
  if auth.role() is not null
     and auth.role() <> 'service_role'
     and not public.is_group_member(p_group_id, auth.uid()) then
    raise exception 'NOT_A_MEMBER';
  end if;

  return query
  with ledger as (
    -- every split: the split person owes the payer
    select s.user_id as d, e.paid_by as c, s.amount_owed as amt
      from public.expense_splits s
      join public.expenses e on e.id = s.expense_id
     where e.group_id = p_group_id
       and s.user_id <> e.paid_by
    union all
    -- every confirmed settlement: payer gave money to receiver, which
    -- works like the receiver now owing the payer that amount
    select st.paid_to, st.paid_by, st.amount
      from public.settlements st
     where st.group_id = p_group_id
       and st.status = 'confirmed'
  ),
  pairs as (
    -- net per unordered pair (a < b): positive = a owes b
    select least(d, c) as a, greatest(d, c) as b,
           sum(case when d < c then amt else -amt end) as net
      from ledger
     group by 1, 2
  )
  select case when net > 0 then a else b end,
         case when net > 0 then b else a end,
         abs(net)
    from pairs
   where net <> 0;
end;
$$;


-- ── 3. For the app: all debts in all my groups, in ONE call ─────────────────
-- pending_amount = settlements the debtor has recorded but the creditor has
-- not confirmed yet (shown, but NOT subtracted from the debt).
CREATE OR REPLACE FUNCTION public.get_my_debts()
RETURNS TABLE (group_id uuid, debtor_id uuid, creditor_id uuid,
               amount numeric, pending_amount numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select g.gid, d.debtor_id, d.creditor_id, d.amount,
         coalesce((
           select sum(st.amount) from public.settlements st
            where st.group_id = g.gid and st.status = 'pending'
              and st.paid_by = d.debtor_id and st.paid_to = d.creditor_id
         ), 0)
    from public.get_my_group_ids() as g(gid)
   cross join lateral public.group_debts(g.gid) d;
end;
$$;


-- ── 4. For the reminder Edge Function only (service role) ───────────────────
-- `since` = how long this debt has existed: the first expense the debtor
-- owes the creditor for, or the last confirmed payment between them if
-- that is later.
CREATE OR REPLACE FUNCTION public.debts_for_reminders()
RETURNS TABLE (group_id uuid, group_name text, currency text,
               debtor_id uuid, creditor_id uuid, amount numeric,
               since timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
begin
  if auth.role() is not null and auth.role() <> 'service_role' then
    raise exception 'NOT_ALLOWED';
  end if;

  return query
  select g.id, g.name, g.currency, d.debtor_id, d.creditor_id, d.amount,
         greatest(
           coalesce((
             select min(e.created_at)
               from public.expense_splits s
               join public.expenses e on e.id = s.expense_id
              where e.group_id = g.id and s.user_id = d.debtor_id
                and e.paid_by = d.creditor_id
           ), now()),
           coalesce((
             select max(coalesce(st.confirmed_at, st.created_at))
               from public.settlements st
              where st.group_id = g.id and st.status = 'confirmed'
                and st.kind = 'payment'
                and ((st.paid_by = d.debtor_id and st.paid_to = d.creditor_id)
                  or (st.paid_by = d.creditor_id and st.paid_to = d.debtor_id))
           ), '-infinity'::timestamptz)
         )
    from public.groups g
   cross join lateral public.group_debts(g.id) d
   where g.is_archived = false;
end;
$$;


-- ── Helper: in-app notification (respects the "settlements" preference) ─────
CREATE OR REPLACE FUNCTION public._notify_settlement(
  p_user_id uuid, p_group_id uuid, p_settlement_id uuid, p_body text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
begin
  insert into public.notifications (user_id, type, title, body, group_id, entity_id)
  select p.id, 'settlement', g.name, p_body, p_group_id, p_settlement_id
    from public.profiles p, public.groups g
   where p.id = p_user_id and g.id = p_group_id
     and coalesce(p.notify_settlements, true);
end;
$$;


-- ── 5. record_settlement ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.record_settlement(
  p_group_id uuid, p_paid_by uuid, p_paid_to uuid, p_amount numeric)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_uid uuid := auth.uid();
  v_debt numeric;
  v_pending numeric;
  v_id uuid := gen_random_uuid();
  v_confirmed boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_group_member(p_group_id, v_uid) then
    raise exception 'NOT_A_MEMBER';
  end if;
  -- Only the two people involved can record a payment between them
  if v_uid is distinct from p_paid_by and v_uid is distinct from p_paid_to then
    raise exception 'NOT_ALLOWED';
  end if;
  if p_amount is null or p_amount <= 0 or p_amount <> round(p_amount, 2) then
    raise exception 'INVALID_AMOUNT';
  end if;

  -- One settlement change at a time per group (no double-paying races)
  perform pg_advisory_xact_lock(hashtext('settle:' || p_group_id::text));

  select d.amount into v_debt
    from public.group_debts(p_group_id) d
   where d.debtor_id = p_paid_by and d.creditor_id = p_paid_to;
  if v_debt is null then
    raise exception 'NO_DEBT';
  end if;

  select coalesce(sum(amount), 0) into v_pending
    from public.settlements
   where group_id = p_group_id and status = 'pending'
     and paid_by = p_paid_by and paid_to = p_paid_to;

  -- Partial payments are fine; more than is still owed is not
  if p_amount > v_debt - v_pending then
    raise exception 'AMOUNT_TOO_HIGH';
  end if;

  -- The receiver saying "I got paid" needs no further confirmation
  v_confirmed := (v_uid = p_paid_to);

  insert into public.settlements
    (id, group_id, paid_by, paid_to, amount, currency, status, kind,
     created_by, confirmed_at)
  select v_id, p_group_id, p_paid_by, p_paid_to, p_amount, g.currency,
         case when v_confirmed then 'confirmed' else 'pending' end,
         'payment', v_uid,
         case when v_confirmed then now() end
    from public.groups g where g.id = p_group_id;

  return v_id;
end;
$$;


-- ── 6. confirm_settlement (receiver only) ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.confirm_settlement(p_settlement_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_uid uuid := auth.uid();
  v_st public.settlements%rowtype;
  v_debt numeric;
  v_name text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_st from public.settlements where id = p_settlement_id;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if v_uid is distinct from v_st.paid_to then
    raise exception 'NOT_ALLOWED';
  end if;

  perform pg_advisory_xact_lock(hashtext('settle:' || v_st.group_id::text));
  select * into v_st from public.settlements where id = p_settlement_id for update;
  if v_st.status <> 'pending' then
    raise exception 'NOT_PENDING';
  end if;

  -- The debt may have shrunk since it was recorded (e.g. an expense was
  -- deleted). Never confirm more than is owed — cancel and record again.
  select d.amount into v_debt
    from public.group_debts(v_st.group_id) d
   where d.debtor_id = v_st.paid_by and d.creditor_id = v_st.paid_to;
  if v_debt is null or v_st.amount > v_debt then
    raise exception 'AMOUNT_TOO_HIGH';
  end if;

  update public.settlements
     set status = 'confirmed', confirmed_at = now()
   where id = p_settlement_id;

  select full_name into v_name from public.profiles where id = v_uid;
  perform public._notify_settlement(
    v_st.paid_by, v_st.group_id, p_settlement_id,
    coalesce(v_name, 'Someone') || ' confirmed your payment of '
      || v_st.currency || ' ' || v_st.amount::text);
end;
$$;


-- ── 7. cancel_settlement (either side, pending only) ────────────────────────
CREATE OR REPLACE FUNCTION public.cancel_settlement(p_settlement_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_uid uuid := auth.uid();
  v_st public.settlements%rowtype;
  v_other uuid;
  v_name text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_st from public.settlements where id = p_settlement_id for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if v_uid is distinct from v_st.paid_by and v_uid is distinct from v_st.paid_to then
    raise exception 'NOT_ALLOWED';
  end if;
  if v_st.status <> 'pending' then
    raise exception 'NOT_PENDING';
  end if;

  update public.settlements
     set status = 'cancelled', cancelled_at = now(), cancelled_by = v_uid
   where id = p_settlement_id;

  v_other := case when v_uid = v_st.paid_by then v_st.paid_to else v_st.paid_by end;
  select full_name into v_name from public.profiles where id = v_uid;
  perform public._notify_settlement(
    v_other, v_st.group_id, p_settlement_id,
    coalesce(v_name, 'Someone') || ' cancelled the payment of '
      || v_st.currency || ' ' || v_st.amount::text);
end;
$$;


-- ── 8. leave_group (blocked while money is owed either way) ─────────────────
CREATE OR REPLACE FUNCTION public.leave_group(p_group_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_group_member(p_group_id, v_uid) then
    raise exception 'NOT_A_MEMBER';
  end if;

  perform pg_advisory_xact_lock(hashtext('settle:' || p_group_id::text));
  if exists (
    select 1 from public.group_debts(p_group_id) d
     where d.debtor_id = v_uid or d.creditor_id = v_uid
  ) then
    raise exception 'HAS_UNSETTLED_DEBTS';
  end if;

  delete from public.group_members
   where group_id = p_group_id and user_id = v_uid;
end;
$$;


-- ── 9. Only the RPCs above can change money data ────────────────────────────
-- Settlements: no direct insert/update (record/confirm/cancel only).
DROP POLICY IF EXISTS "Members can insert settlements" ON public.settlements;
REVOKE INSERT, UPDATE, DELETE ON public.settlements FROM anon, authenticated;

-- Splits: is_settled no longer matters, nobody updates splits directly.
DROP POLICY IF EXISTS "Payer can mark splits settled" ON public.expense_splits;
REVOKE UPDATE ON public.expense_splits FROM anon, authenticated;

-- Leaving: only through leave_group() (it checks for debts). Admins can
-- still remove members ("Admins can remove members" stays).
DROP POLICY IF EXISTS "Users can leave groups" ON public.group_members;
