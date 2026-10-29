-- ============================================================================
-- Splitly — safer account deletion (APP_REVIEW_v2.md §5, §6)
--
-- delete_own_account(), all in ONE transaction:
--   1. Refused with HAS_UNSETTLED_DEBTS while the user owes or is owed money
--      in ANY of their groups (archived ones too) — the same rule as
--      leave_group. Nothing is changed then.
--   2. Anonymizes as before ("Deleted User", no phone, no push token, login
--      blocked) and also clears avatar_url. (The photo FILE is deleted by
--      the app through the Storage API — Postgres may not delete storage
--      files directly.)
--   3. Leaves every group. Other people's history stays complete: expenses,
--      splits, payments and messages point to the PROFILE (kept as "Deleted
--      User"), not to the membership.
--        * a group they created is handed to another admin, otherwise to
--          the longest-standing member (who becomes admin);
--        * a group with nobody else left is archived.
--   4. Stops recurring expenses they pay or are in the split of (every
--      future copy would be skipped anyway). Copies made so far stay.
--   5. Removes their own notifications, typing and chat-read status.
--      Their messages and chat photos stay (group history).
--
-- profiles.deleted_at marks a deleted account. Profiles are normally only
-- readable by group-mates; a deleted user has no groups any more, so their
-- old expenses would show "Unknown". Deleted profiles hold nothing private
-- ("Deleted User", a color), so any signed-in user may read them. Only this
-- function sets deleted_at (a trigger stops users from changing it).
-- Accounts deleted before this migration are marked too.
--
-- Safe on a database with data and safe to run twice.
-- ============================================================================

-- ── deleted_at + who may read deleted profiles ──────────────────────────────
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

UPDATE public.profiles p
   SET deleted_at = coalesce(u.updated_at, now())
  FROM auth.users u
 WHERE u.id = p.id
   AND u.email LIKE 'deleted-%@splitly.deleted'
   AND p.deleted_at IS NULL;

DROP POLICY IF EXISTS "Signed-in users can read deleted profiles" ON public.profiles;
CREATE POLICY "Signed-in users can read deleted profiles" ON public.profiles
  FOR SELECT TO authenticated
  USING (deleted_at IS NOT NULL);

-- Users update their own profile row directly; they must not be able to
-- set (or clear) deleted_at, which would make their profile readable by all.
CREATE OR REPLACE FUNCTION public._guard_profile_deleted_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
begin
  if coalesce(auth.role(), '') in ('anon', 'authenticated')
     and current_user in ('anon', 'authenticated')
     and new.deleted_at is distinct from
         (case when tg_op = 'UPDATE' then old.deleted_at end) then
    raise exception 'NOT_ALLOWED';
  end if;
  return new;
end;
$$;

DROP TRIGGER IF EXISTS profiles_guard_deleted_at ON public.profiles;
CREATE TRIGGER profiles_guard_deleted_at
  BEFORE INSERT OR UPDATE OF deleted_at ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public._guard_profile_deleted_at();


CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
declare
  v_uid uuid := auth.uid();
  v_group uuid;
  v_heir uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- 1. No open money anywhere. Lock each group like the payment functions,
  --    so a payment recorded at this moment can't slip past the check.
  for v_group in
    select group_id from public.group_members where user_id = v_uid order by group_id
  loop
    perform pg_advisory_xact_lock(hashtext('settle:' || v_group::text));
    if exists (
      select 1 from public.group_debts(v_group) d
       where d.debtor_id = v_uid or d.creditor_id = v_uid
    ) then
      raise exception 'HAS_UNSETTLED_DEBTS';
    end if;
  end loop;

  -- 3a. Groups they created get a new owner (or are archived when empty)
  for v_group in
    select g.id from public.groups g
      join public.group_members m on m.group_id = g.id and m.user_id = v_uid
     where g.created_by = v_uid
  loop
    select m.user_id into v_heir
      from public.group_members m
     where m.group_id = v_group and m.user_id <> v_uid
     order by (m.role = 'admin') desc, m.joined_at asc nulls last, m.id
     limit 1;

    if v_heir is null then
      update public.groups set is_archived = true where id = v_group;
    else
      update public.groups set created_by = v_heir where id = v_group;
      update public.group_members set role = 'admin'
       where group_id = v_group and user_id = v_heir;
    end if;
  end loop;

  -- 4. Stop recurring expenses they pay or are part of
  update public.expenses e
     set is_recurring = false, recur_paused = false, next_recur_at = null,
         updated_at = now()
   where e.is_recurring
     and (e.paid_by = v_uid
          or exists (select 1 from public.expense_splits s
                      where s.expense_id = e.id and s.user_id = v_uid));

  -- 3b. Leave every group
  delete from public.group_members where user_id = v_uid;

  -- 5. Personal leftovers
  delete from public.notifications where user_id = v_uid;
  delete from public.typing_status where user_id = v_uid;
  delete from public.chat_read_status where user_id = v_uid;

  -- 2. Anonymize the profile — the row stays so other members' expense and
  --    balance history with this person remains intact and correct.
  update public.profiles
     set full_name  = 'Deleted User',
         phone      = null,
         fcm_token  = null,
         avatar_url = null,
         deleted_at = now()
   where id = v_uid;

  -- Scramble the login + ban the account so it can never sign in again.
  -- The auth.users row itself is NOT deleted: that would cascade to the
  -- profile and break the expenses this user paid for.
  update auth.users
     set email              = 'deleted-' || v_uid || '@splitly.deleted',
         phone              = null,
         encrypted_password = '',
         banned_until       = '2999-12-31',
         raw_user_meta_data = '{}'::jsonb
   where id = v_uid;
end;
$$;
