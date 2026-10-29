-- ============================================================================
-- Splitly — Phase 4 small fixes (APP_REVIEW_v2.md §10)
--
-- 1. set_group_archived(group, true/false): the creator or a group admin
--    archives / unarchives. Anyone else gets NOT_ALLOWED (before, the direct
--    UPDATE silently changed nothing and the app showed success).
-- 2. Edit history + notifications:
--      expense_edits   one row per edit: who, when, what changed (before → after)
--      edit_expense    saves that row and an in-app notification
--                      ('expense_edited') for the payer and everyone in the old
--                      or new split, except the editor, unless they muted
--                      expenses. The push goes out through notifications_push.
--    An edit that changes nothing is not saved and notifies nobody.
-- 3. delete_expense: the payer OR a group admin (same rule as edit_expense).
-- 4. delete_expense takes the same per-group lock as the payment functions,
--    so a delete and a payment confirm can never run at the same moment
--    (tests/delete_confirm_race_test.sh).
--
-- Error codes: NOT_ALLOWED, NOT_A_MEMBER, EXPENSE_NOT_FOUND (+ add_expense codes)
--
-- Safe on a database with data and safe to run twice: CREATE ... IF NOT
-- EXISTS / OR REPLACE, DROP ... IF EXISTS + CREATE, no rows are changed.
-- No REVOKE EXECUTE (see 20261027120000_security_fixes.sql §5).
-- ============================================================================


-- ── 1. Archive / unarchive ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_group_archived(
  p_group_id uuid, p_archived boolean)
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
  if not (public.is_group_creator(p_group_id) or public.is_group_admin(p_group_id)) then
    raise exception 'NOT_ALLOWED';
  end if;

  update public.groups
     set is_archived = coalesce(p_archived, false)
   where id = p_group_id;
end;
$$;


-- ── 2a. Edit history table ──────────────────────────────────────────────────
-- changes: {"amount": {"from": 300, "to": 400},
--           "splits": {"from": {"<user>": 150, ...}, "to": {...}}, ...}
CREATE TABLE IF NOT EXISTS public.expense_edits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id uuid NOT NULL REFERENCES public.expenses(id) ON DELETE CASCADE,
  group_id uuid NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  edited_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  edited_at timestamptz NOT NULL DEFAULT now(),
  changes jsonb NOT NULL
);

CREATE INDEX IF NOT EXISTS expense_edits_expense_idx
  ON public.expense_edits (expense_id, edited_at DESC);

ALTER TABLE public.expense_edits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can read edit history" ON public.expense_edits;
CREATE POLICY "Members can read edit history" ON public.expense_edits
  FOR SELECT TO authenticated
  USING (group_id IN (SELECT public.get_my_group_ids()));

-- Only edit_expense() writes it
REVOKE INSERT, UPDATE, DELETE ON public.expense_edits FROM anon, authenticated;


-- ── 2b. edit_expense: history + notifications ───────────────────────────────
-- Same signature, checks and lock as 20261030000100_edit_expense.sql.
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
  v_old_splits jsonb;
  v_new_splits jsonb;
  v_title text := trim(p_title);
  v_category text := coalesce(p_category, 'other');
  v_notes text := nullif(trim(coalesce(p_notes, '')), '');
  v_date date;
  v_changes jsonb := '{}'::jsonb;
  v_editor text;
  v_group text;
  v_summary text;
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
  select * into v_exp from public.expenses where id = p_expense_id for update;
  v_date := coalesce(p_expense_date, v_exp.expense_date);

  -- What changed?
  select coalesce(jsonb_object_agg(user_id::text, amount_owed), '{}'::jsonb)
    into v_old_splits
    from public.expense_splits where expense_id = p_expense_id;
  select coalesce(jsonb_object_agg(s.user_id::text, s.amount_owed), '{}'::jsonb)
    into v_new_splits
    from jsonb_to_recordset(p_splits) as s(user_id uuid, amount_owed numeric);

  if v_title is distinct from v_exp.title then
    v_changes := v_changes || jsonb_build_object('title',
      jsonb_build_object('from', v_exp.title, 'to', v_title));
  end if;
  if p_amount <> v_exp.amount then
    v_changes := v_changes || jsonb_build_object('amount',
      jsonb_build_object('from', v_exp.amount, 'to', p_amount));
  end if;
  if v_date is distinct from v_exp.expense_date then
    v_changes := v_changes || jsonb_build_object('date',
      jsonb_build_object('from', v_exp.expense_date, 'to', v_date));
  end if;
  if v_category is distinct from v_exp.category then
    v_changes := v_changes || jsonb_build_object('category',
      jsonb_build_object('from', v_exp.category, 'to', v_category));
  end if;
  if v_notes is distinct from v_exp.notes then
    v_changes := v_changes || jsonb_build_object('notes',
      jsonb_build_object('from', v_exp.notes, 'to', v_notes));
  end if;
  if p_split_type is distinct from v_exp.split_type then
    v_changes := v_changes || jsonb_build_object('split_type',
      jsonb_build_object('from', v_exp.split_type, 'to', p_split_type));
  end if;
  if v_new_splits <> v_old_splits then
    v_changes := v_changes || jsonb_build_object('splits',
      jsonb_build_object('from', v_old_splits, 'to', v_new_splits));
  end if;

  -- Nothing changed → nothing to save, nobody to tell
  if v_changes = '{}'::jsonb then
    return;
  end if;

  update public.expenses
     set title        = v_title,
         amount       = p_amount,
         category     = v_category,
         split_type   = p_split_type,
         notes        = v_notes,
         expense_date = v_date,
         edited_at    = now(),
         updated_at   = now()
   where id = p_expense_id;

  delete from public.expense_splits where expense_id = p_expense_id;
  insert into public.expense_splits (expense_id, user_id, amount_owed, is_settled)
  select p_expense_id, s.user_id, s.amount_owed, false
    from jsonb_to_recordset(p_splits) as s(user_id uuid, amount_owed numeric);

  insert into public.expense_edits (expense_id, group_id, edited_by, changes)
  values (p_expense_id, v_exp.group_id, v_uid, v_changes);

  -- Tell the people it affects (not the editor; respects "mute expenses")
  select full_name into v_editor from public.profiles where id = v_uid;
  select name into v_group from public.groups where id = v_exp.group_id;
  v_summary := coalesce(v_editor, 'Someone') || ' changed "' || v_title || '"'
    || case when v_changes ? 'amount'
            then ': ' || v_exp.currency || ' ' || to_char(v_exp.amount, 'FM999999990.00')
                 || ' → ' || v_exp.currency || ' ' || to_char(p_amount, 'FM999999990.00')
            else '' end
    || '.';

  insert into public.notifications (user_id, type, title, body, group_id, entity_id)
  select p.id, 'expense_edited', coalesce(v_group, 'Splitly'),
         v_summary
           || case when coalesce((v_old_splits ->> p.id::text)::numeric, 0)
                        <> coalesce((v_new_splits ->> p.id::text)::numeric, 0)
                   then ' Your share: ' || v_exp.currency || ' '
                        || to_char(coalesce((v_old_splits ->> p.id::text)::numeric, 0), 'FM999999990.00')
                        || ' → ' || v_exp.currency || ' '
                        || to_char(coalesce((v_new_splits ->> p.id::text)::numeric, 0), 'FM999999990.00')
                        || '.'
                   else '' end,
         v_exp.group_id, p_expense_id
    from public.profiles p
   where p.id in (
           select v_exp.paid_by
           union select k::uuid from jsonb_object_keys(v_old_splits) k
           union select k::uuid from jsonb_object_keys(v_new_splits) k)
     and p.id <> v_uid
     and coalesce(p.notify_expenses, true)
     and public.is_group_member(v_exp.group_id, p.id);
end;
$$;


-- ── 3 + 4. delete_expense: payer or admin, under the group lock ─────────────
-- SECURITY DEFINER now (the table's DELETE rule only allows the payer), so
-- it checks everything itself. Someone outside the group gets
-- EXPENSE_NOT_FOUND, exactly as before (they couldn't see it).
CREATE OR REPLACE FUNCTION public.delete_expense(p_expense_id uuid)
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
  if not found or not public.is_group_member(v_exp.group_id, v_uid) then
    raise exception 'EXPENSE_NOT_FOUND';
  end if;
  if v_uid <> v_exp.paid_by and not public.is_group_admin(v_exp.group_id) then
    raise exception 'NOT_ALLOWED';
  end if;

  -- Same lock as record/confirm/cancel_settlement and edit_expense: a
  -- payment confirmed at this moment waits, then sees the smaller debt.
  perform pg_advisory_xact_lock(hashtext('settle:' || v_exp.group_id::text));

  delete from public.expenses where id = p_expense_id;
end;
$$;


-- ── 5. Push for edit notifications too ──────────────────────────────────────
-- Same trigger function as 20261030000200 (_push_notification_row).
DROP TRIGGER IF EXISTS notifications_push ON public.notifications;
CREATE TRIGGER notifications_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  WHEN (new.type IN ('recurring_skipped', 'expense_edited'))
  EXECUTE FUNCTION public._push_notification_row();
