-- ============================================================================
-- Splitly — deleted accounts: nothing personal left in auth either
--
-- _scrub_deleted_profiles() (20261031000200) cleaned the public profile and
-- auth.identities. Now it also cleans Supabase Auth's own tables for every
-- deleted user (profiles.deleted_at is set):
--
--   auth.users   email → deleted-<id>@deleted.invalid (a reserved domain that
--                can never receive mail), phone / password / name + picture
--                (raw_user_meta_data) / provider info (raw_app_meta_data) /
--                pending email or phone changes / every one-time code and
--                every sign-in or confirmation time emptied; signup and
--                update time → the deletion day; login banned for good.
--   auth.identities, sessions (IP address, phone model), refresh_tokens,
--   mfa_factors (phone), one_time_tokens (email), flow_state (Google
--   tokens), audit_log_entries (email, IP)   → deleted.
--
-- Because the old email and the Google account are no longer linked to the
-- deleted user, the same person can sign up again (email or Google) — as a
-- NEW account with nothing of the old one. The old account can never log
-- in: no password, no identity, banned.
--
-- delete_own_account() no longer updates auth.users itself; the scrub does
-- it. The migration runs the scrub once for every account deleted so far
-- (their old "deleted-<id>@splitly.deleted" emails get the new format).
--
-- Safe on a database with data and safe to run twice.
-- ============================================================================


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

  -- ── Public profile: the same for every deleted user apart from the id ──
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

  -- ── Supabase Auth: the account row stays (expenses point to the profile,
  --    which points to it) but holds nothing personal and can't log in ──
  update auth.users u
     set email                      = 'deleted-' || u.id || '@deleted.invalid',
         phone                      = null,
         encrypted_password         = '',
         raw_user_meta_data         = '{}'::jsonb,
         raw_app_meta_data          = '{}'::jsonb,
         email_change               = '',
         phone_change               = '',
         confirmation_token         = '',
         recovery_token             = '',
         email_change_token_new     = '',
         email_change_token_current = '',
         phone_change_token         = '',
         reauthentication_token     = '',
         email_confirmed_at         = null,
         phone_confirmed_at         = null,
         invited_at                 = null,
         confirmation_sent_at       = null,
         recovery_sent_at           = null,
         email_change_sent_at       = null,
         phone_change_sent_at       = null,
         reauthentication_sent_at   = null,
         last_sign_in_at            = null,
         created_at                 = p.deleted_at,
         updated_at                 = p.deleted_at,
         banned_until               = '2999-12-31'
    from public.profiles p
   where p.id = u.id
     and p.deleted_at is not null
     and (p_user is null or p.id = p_user);

  -- Everything else Auth keeps about the person
  delete from auth.identities i using public.profiles p
   where i.user_id = p.id and p.deleted_at is not null and (p_user is null or p.id = p_user);
  delete from auth.sessions s using public.profiles p
   where s.user_id = p.id and p.deleted_at is not null and (p_user is null or p.id = p_user);
  delete from auth.refresh_tokens r using public.profiles p
   where r.user_id = p.id::text and p.deleted_at is not null and (p_user is null or p.id = p_user);
  delete from auth.mfa_factors f using public.profiles p
   where f.user_id = p.id and p.deleted_at is not null and (p_user is null or p.id = p_user);
  delete from auth.one_time_tokens o using public.profiles p
   where o.user_id = p.id and p.deleted_at is not null and (p_user is null or p.id = p_user);
  delete from auth.flow_state f using public.profiles p
   where f.user_id = p.id and p.deleted_at is not null and (p_user is null or p.id = p_user);
  delete from auth.audit_log_entries a using public.profiles p
   where a.payload ->> 'actor_id' = p.id::text and p.deleted_at is not null
     and (p_user is null or p.id = p_user);

  return v_count;
end;
$$;


-- delete_own_account: same as 20261031000200, but the auth.users part is
-- now done by the scrub.
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

  -- 5. Mark deleted, then scrub the profile AND the Auth data. The profile
  --    row stays so other members' history remains intact and correct; the
  --    login is emptied and banned.
  update public.profiles set deleted_at = now() where id = v_uid;
  perform public._scrub_deleted_profiles(v_uid);
end;
$$;


-- Every account deleted so far
SELECT public._scrub_deleted_profiles(NULL);
