-- ============================================================================
-- Splitly — deleted profiles hold nothing that can identify the person
--
-- Since 20261031000100 any signed-in user can read a DELETED profile (so old
-- expenses show "Deleted User"). That migration cleared only name, phone,
-- push token and photo link, and it also opened up accounts deleted BEFORE
-- it, whose photo link the old function never cleared.
--
-- Now every deleted profile is the same apart from its id:
--   full_name 'Deleted User', avatar_color default, phone / fcm_token /
--   avatar_url / created_at empty, all notify_* settings back to default,
--   deleted_at = the DAY only (not the exact second).
-- The id stays: old expenses, splits and messages point to it.
--
-- _scrub_deleted_profiles(user) does this for one deleted user, or for all
-- of them (NULL). delete_own_account() uses it, and this migration runs it
-- once for every account deleted so far. It also removes the person's rows
-- in auth.identities (real email; for Google also name + picture link),
-- which the login no longer needs (it is banned).
--
-- NOT possible from SQL: deleting old accounts' photo FILES in Storage
-- (Postgres may not delete storage files). Those are listed and removed
-- through the Storage API at go-live.
--
-- Safe on a database with data and safe to run twice.
-- ============================================================================


-- ── 1. One place that defines "scrubbed" ────────────────────────────────────
CREATE OR REPLACE FUNCTION public._scrub_deleted_profiles(p_user uuid DEFAULT NULL)
RETURNS integer
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public, auth
AS $$
declare
  v_count integer;
begin
  -- Runs as its CALLER. From delete_own_account() (SECURITY DEFINER) or a
  -- migration that is the database owner; called directly through the API
  -- it would be the app user — refused. (Checking auth.role() would refuse
  -- delete_own_account too: the user's JWT is still active there.)
  if current_user in ('anon', 'authenticated') then
    raise exception 'NOT_ALLOWED';
  end if;

  update public.profiles
     set full_name             = 'Deleted User',
         phone                 = null,
         fcm_token             = null,
         avatar_url            = null,
         avatar_color          = '#0F766E',
         created_at            = null,
         notify_messages       = true,
         notify_expenses       = true,
         notify_settlements    = true,
         notify_members        = true,
         notify_debt_reminders = true,
         deleted_at            = date_trunc('day', deleted_at)
   where deleted_at is not null
     and (p_user is null or id = p_user);
  get diagnostics v_count = row_count;

  delete from auth.identities i
   using public.profiles p
   where i.user_id = p.id
     and p.deleted_at is not null
     and (p_user is null or p.id = p_user);

  return v_count;
end;
$$;


-- ── 2. delete_own_account uses it ───────────────────────────────────────────
-- Same as 20261031000100_account_deletion.sql, except the profile part.
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

  -- 2. Groups they created get a new owner (or are archived when empty)
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

  -- 3. Stop recurring expenses they pay or are part of
  update public.expenses e
     set is_recurring = false, recur_paused = false, next_recur_at = null,
         updated_at = now()
   where e.is_recurring
     and (e.paid_by = v_uid
          or exists (select 1 from public.expense_splits s
                      where s.expense_id = e.id and s.user_id = v_uid));

  -- 4. Leave every group; personal leftovers
  delete from public.group_members where user_id = v_uid;
  delete from public.notifications where user_id = v_uid;
  delete from public.typing_status where user_id = v_uid;
  delete from public.chat_read_status where user_id = v_uid;

  -- 5. Mark deleted, then scrub everything that could identify them. The
  --    row stays so other members' history remains intact and correct.
  update public.profiles set deleted_at = now() where id = v_uid;
  perform public._scrub_deleted_profiles(v_uid);

  -- 6. Scramble the login + ban the account so it can never sign in again.
  --    The auth.users row itself is NOT deleted: that would cascade to the
  --    profile and break the expenses this user paid for.
  update auth.users
     set email              = 'deleted-' || v_uid || '@splitly.deleted',
         phone              = null,
         encrypted_password = '',
         banned_until       = '2999-12-31',
         raw_user_meta_data = '{}'::jsonb
   where id = v_uid;
end;
$$;


-- ── 3. Clean every account deleted so far ───────────────────────────────────
SELECT public._scrub_deleted_profiles(NULL);
