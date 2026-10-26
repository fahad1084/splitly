-- ============================================================================
-- Splitly — security fixes (APP_REVIEW.md §5, fix #3 part 2)
--
-- Fixes:
--   0. delete_group_permanently() could be called by anyone, even logged out,
--      and deleted any group (auth.uid() NULL slipped past the `<>` check)
--   1. Joining a group without the invite code (direct INSERT into
--      group_members) → now only through join_group_by_code()
--   2. Members making themselves admin (leave + re-insert as admin)
--   3. Any member marking any split as settled → only the person who is
--      owed the money (the expense payer) can, and only is_settled/settled_at
--   4. Expenses/splits/settlements with non-members, negative amounts,
--      duplicate splits → membership checks + CHECK/UNIQUE/NOT NULL
--   5. Server functions callable by `anon` → each function now rejects
--      logged-out / app callers in its own body. (NOT with REVOKE EXECUTE:
--      on Postgres 17.6.1.104 a "permission denied for function" error
--      crashes the whole database server — tested on the local stack.)
--   6. Public chat attachments → private bucket, members only (app uses
--      signed URLs); avatars/group photos can't be overwritten by others
--   7. "infinite recursion detected in policy for relation group_members"
--      on EVERY update/delete of group_members (leave group, remove
--      member, make admin all failed) — the admin policies read
--      group_members inside a group_members policy; now via is_group_admin()
--
-- Safe to run on a database with data and safe to run twice:
--   * stops with a clear message (and changes nothing) if existing rows
--     break one of the new rules
--   * policies: DROP POLICY IF EXISTS + CREATE POLICY
--   * constraints: DROP CONSTRAINT IF EXISTS + ADD CONSTRAINT
--   * functions: CREATE OR REPLACE
--   * no rows are deleted or changed (except chat-attachments bucket → private)
-- ============================================================================


-- ── 0. Pre-check existing data ──────────────────────────────────────────────
DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.expenses
   WHERE amount <= 0 OR group_id IS NULL OR paid_by IS NULL;
  IF n > 0 THEN RAISE EXCEPTION
    'security_fixes: % expense(s) have amount <= 0 or no group/payer. Fix or delete them, then run again.', n;
  END IF;

  SELECT count(*) INTO n FROM public.expense_splits
   WHERE amount_owed < 0 OR expense_id IS NULL OR user_id IS NULL;
  IF n > 0 THEN RAISE EXCEPTION
    'security_fixes: % split(s) have a negative amount or no expense/user.', n;
  END IF;

  SELECT count(*) INTO n FROM (
    SELECT 1 FROM public.expense_splits GROUP BY expense_id, user_id HAVING count(*) > 1
  ) d;
  IF n > 0 THEN RAISE EXCEPTION
    'security_fixes: % expense(s) have the same person split twice.', n;
  END IF;

  SELECT count(*) INTO n FROM public.settlements
   WHERE amount <= 0 OR paid_by IS NULL OR paid_to IS NULL OR group_id IS NULL
      OR paid_by = paid_to;
  IF n > 0 THEN RAISE EXCEPTION
    'security_fixes: % settlement(s) have amount <= 0, a missing person/group, or pay themselves.', n;
  END IF;

  SELECT count(*) INTO n FROM public.group_members
   WHERE role IS NULL OR role NOT IN ('admin', 'member')
      OR group_id IS NULL OR user_id IS NULL;
  IF n > 0 THEN RAISE EXCEPTION
    'security_fixes: % membership row(s) have a bad role or no group/user.', n;
  END IF;
END $$;


-- ── Helper: is a given user a member of a given group? ──────────────────────
-- SECURITY DEFINER so it can be used inside RLS policies without recursion.
CREATE OR REPLACE FUNCTION public.is_group_member(p_group_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM group_members
     WHERE group_id = p_group_id AND user_id = p_user_id
  );
$$;


-- ── Helper: is the CURRENT user an admin of a group? ────────────────────────
-- Used by the group_members policies below. A policy on group_members must
-- not read group_members directly (Postgres stops with "infinite
-- recursion"); a SECURITY DEFINER function reads it without RLS.
CREATE OR REPLACE FUNCTION public.is_group_admin(p_group_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM group_members
     WHERE group_id = p_group_id AND user_id = auth.uid() AND role = 'admin'
  );
$$;


-- ── 0. delete_group_permanently: reject logged-out callers ──────────────────
-- Old version: `if v_creator <> auth.uid()` is NULL (not true) when
-- auth.uid() is NULL, so the check was skipped and the delete ran.
CREATE OR REPLACE FUNCTION public.delete_group_permanently(p_group_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_creator uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  select created_by into v_creator from public.groups where id = p_group_id;
  if v_creator is null then
    raise exception 'Group not found';
  end if;
  if v_creator is distinct from auth.uid() then
    raise exception 'Only the group creator can permanently delete this group';
  end if;
  delete from public.chat_read_status where group_id = p_group_id;
  delete from public.typing_status where group_id = p_group_id;
  delete from public.messages where group_id = p_group_id;
  delete from public.settlements where group_id = p_group_id;
  delete from public.expense_splits
    where expense_id in (select id from public.expenses where group_id = p_group_id);
  delete from public.expenses where group_id = p_group_id;
  delete from public.group_members where group_id = p_group_id;
  delete from public.groups where id = p_group_id;
end;
$$;


-- ── 1. Join only through the invite code ────────────────────────────────────
-- Returns one row when the code is valid, no rows when it is not.
-- Always joins as 'member', never as admin.
CREATE OR REPLACE FUNCTION public.join_group_by_code(p_invite_code text)
RETURNS TABLE (group_id uuid, group_name text, already_member boolean)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_uid uuid := auth.uid();
  v_group_id uuid;
  v_group_name text;
  v_inserted int;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select g.id, g.name into v_group_id, v_group_name
    from public.groups g
   where g.invite_code = lower(trim(p_invite_code))
     and g.is_archived = false;

  if v_group_id is null then
    return;  -- invalid code → empty result
  end if;

  insert into public.group_members (group_id, user_id, role)
  values (v_group_id, v_uid, 'member')
  on conflict on constraint group_members_group_id_user_id_key do nothing;
  get diagnostics v_inserted = row_count;

  return query select v_group_id, v_group_name, (v_inserted = 0);
end;
$$;

DROP POLICY IF EXISTS "Users can insert into group_members" ON public.group_members;
-- Still needed by "Create group" (until step 4 moves it into an RPC):
-- the creator adds themselves as the first admin. Nobody else can insert.
DROP POLICY IF EXISTS "Creator can add self as admin" ON public.group_members;
CREATE POLICY "Creator can add self as admin" ON public.group_members
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND role = 'admin' AND public.is_group_creator(group_id));


-- ── 2. Roles: only 'admin'/'member', admins can change ONLY the role ────────
ALTER TABLE public.group_members
  ALTER COLUMN group_id SET NOT NULL,
  ALTER COLUMN user_id SET NOT NULL,
  ALTER COLUMN role SET NOT NULL;
ALTER TABLE public.group_members DROP CONSTRAINT IF EXISTS group_members_role_check;
ALTER TABLE public.group_members
  ADD CONSTRAINT group_members_role_check CHECK (role IN ('admin', 'member'));

-- (7) Same rules as before, but via is_group_admin() — no more recursion.
DROP POLICY IF EXISTS "Admins can update member roles" ON public.group_members;
CREATE POLICY "Admins can update member roles" ON public.group_members
  FOR UPDATE TO authenticated
  USING (public.is_group_creator(group_id) OR public.is_group_admin(group_id))
  WITH CHECK (public.is_group_creator(group_id) OR public.is_group_admin(group_id));

DROP POLICY IF EXISTS "Admins can remove members" ON public.group_members;
CREATE POLICY "Admins can remove members" ON public.group_members
  FOR DELETE TO authenticated
  USING (public.is_group_creator(group_id) OR public.is_group_admin(group_id));

REVOKE UPDATE ON public.group_members FROM anon, authenticated;
GRANT UPDATE (role) ON public.group_members TO authenticated;


-- ── 3. Only the person who is owed can mark splits as settled ───────────────
DROP POLICY IF EXISTS "Members can update splits in their groups" ON public.expense_splits;
DROP POLICY IF EXISTS "Payer can mark splits settled" ON public.expense_splits;
CREATE POLICY "Payer can mark splits settled" ON public.expense_splits
  FOR UPDATE TO authenticated
  USING (expense_id IN (SELECT id FROM public.expenses WHERE paid_by = auth.uid()))
  WITH CHECK (expense_id IN (SELECT id FROM public.expenses WHERE paid_by = auth.uid()));

REVOKE UPDATE ON public.expense_splits FROM anon, authenticated;
GRANT UPDATE (is_settled, settled_at) ON public.expense_splits TO authenticated;

-- A settlement can only be recorded by the person receiving the money,
-- with someone from the same group.
DROP POLICY IF EXISTS "Members can insert settlements" ON public.settlements;
CREATE POLICY "Members can insert settlements" ON public.settlements
  FOR INSERT TO authenticated
  WITH CHECK (
    paid_to = auth.uid()
    AND group_id IN (SELECT public.get_my_group_ids())
    AND public.is_group_member(group_id, paid_by)
  );


-- ── 4. Only real group members in expenses/splits; sane amounts ─────────────
DROP POLICY IF EXISTS "Members can insert expenses" ON public.expenses;
CREATE POLICY "Members can insert expenses" ON public.expenses
  FOR INSERT TO authenticated
  WITH CHECK (
    group_id IN (SELECT public.get_my_group_ids())
    AND public.is_group_member(group_id, paid_by)
  );

-- The app never updates expenses (recurring copies run as SECURITY DEFINER),
-- and this policy let a payer move an expense into a group they're not in.
DROP POLICY IF EXISTS "Members can update own expenses" ON public.expenses;

DROP POLICY IF EXISTS "Members can insert splits" ON public.expense_splits;
CREATE POLICY "Members can insert splits" ON public.expense_splits
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.expenses e
     WHERE e.id = expense_splits.expense_id
       AND e.group_id IN (SELECT public.get_my_group_ids())
       AND public.is_group_member(e.group_id, expense_splits.user_id)
  ));

ALTER TABLE public.expenses
  ALTER COLUMN group_id SET NOT NULL,
  ALTER COLUMN paid_by SET NOT NULL;
ALTER TABLE public.expenses DROP CONSTRAINT IF EXISTS expenses_amount_positive;
ALTER TABLE public.expenses
  ADD CONSTRAINT expenses_amount_positive CHECK (amount > 0);

ALTER TABLE public.expense_splits
  ALTER COLUMN expense_id SET NOT NULL,
  ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.expense_splits DROP CONSTRAINT IF EXISTS expense_splits_amount_not_negative;
ALTER TABLE public.expense_splits
  ADD CONSTRAINT expense_splits_amount_not_negative CHECK (amount_owed >= 0);
ALTER TABLE public.expense_splits DROP CONSTRAINT IF EXISTS expense_splits_expense_user_key;
ALTER TABLE public.expense_splits
  ADD CONSTRAINT expense_splits_expense_user_key UNIQUE (expense_id, user_id);

ALTER TABLE public.settlements
  ALTER COLUMN group_id SET NOT NULL,
  ALTER COLUMN paid_by SET NOT NULL,
  ALTER COLUMN paid_to SET NOT NULL;
ALTER TABLE public.settlements DROP CONSTRAINT IF EXISTS settlements_amount_positive;
ALTER TABLE public.settlements
  ADD CONSTRAINT settlements_amount_positive CHECK (amount > 0);
ALTER TABLE public.settlements DROP CONSTRAINT IF EXISTS settlements_not_self;
ALTER TABLE public.settlements
  ADD CONSTRAINT settlements_not_self CHECK (paid_by <> paid_to);


-- ── 5. Function access ──────────────────────────────────────────────────────
-- Every public function can be called through the API by anon and
-- authenticated (Supabase default). We do NOT use REVOKE EXECUTE: on this
-- Postgres build (17.6.1.104) a "permission denied for function" error
-- crashes the database server (segfault, all connections dropped) — tested
-- on the local stack. Instead every function guards itself:
--   delete_group_permanently  → raises 'Not authenticated' (above)
--   delete_own_account        → already raises 'Not authenticated'
--   join_group_by_code        → raises 'Not authenticated' (above)
--   get_unread_counts         → only returns rows for auth.uid() (none when logged out)
--   get_group_preview_by_invite_code → returns nothing when logged out (below)
--   generate_recurring_expenses      → only pg_cron may run it (below)
--   get_my_group_ids / is_group_* / is_authenticated → read-only, empty/false when logged out

CREATE OR REPLACE FUNCTION public.get_group_preview_by_invite_code(p_invite_code text)
RETURNS TABLE(id uuid, name text, description text, currency text, category text, photo_url text)
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  select id, name, description, currency, category, photo_url
  from groups
  where invite_code = p_invite_code
    and is_archived = false
    and auth.uid() is not null;
$$;

-- Same body as before, plus a guard: requests through the API carry a JWT
-- role ('anon' or 'authenticated'); pg_cron runs with no JWT at all.
CREATE OR REPLACE FUNCTION public.generate_recurring_expenses()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
declare
  rec record;
  new_expense_id uuid;
  interval_step interval;
begin
  if coalesce(auth.role(), '') in ('anon', 'authenticated') then
    raise exception 'Not allowed';
  end if;

  for rec in
    select * from public.expenses
    where is_recurring = true
      and next_recur_at is not null
      and next_recur_at <= now()
  loop
    new_expense_id := gen_random_uuid();
    -- interval for this expense's frequency
    interval_step := case rec.recur_every
      when 'daily' then interval '1 day'
      when 'weekly' then interval '7 days'
      when 'monthly' then interval '1 month'
      else interval '1 month'
    end;
    -- Clone the expense as a fresh (non-recurring) entry
    insert into public.expenses (
      id, group_id, paid_by, title, amount, currency, category,
      split_type, notes, is_recurring, recur_every, next_recur_at, created_at
    ) values (
      new_expense_id, rec.group_id, rec.paid_by, rec.title, rec.amount,
      rec.currency, rec.category, rec.split_type, rec.notes,
      false, null, null, now()
    );
    -- Clone its splits
    insert into public.expense_splits (id, expense_id, user_id, amount_owed, is_settled)
    select gen_random_uuid(), new_expense_id, user_id, amount_owed, false
    from public.expense_splits
    where expense_id = rec.id;
    -- Advance the ORIGINAL recurring template to its next due date
    update public.expenses
    set next_recur_at = rec.next_recur_at + interval_step
    where id = rec.id;
  end loop;
end;
$$;


-- ── 6. Storage ──────────────────────────────────────────────────────────────
-- Chat photos + voice notes: private. Files live at {group_id}/{file}; only
-- members of that group can read or upload. The app shows them with
-- short-lived signed URLs.
UPDATE storage.buckets SET public = false WHERE id = 'chat-attachments';

DROP POLICY IF EXISTS "Anyone can view chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Members can view chat attachments" ON storage.objects;
CREATE POLICY "Members can view chat attachments" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'chat-attachments'
    AND (storage.foldername(name))[1] IN (SELECT g::text FROM public.get_my_group_ids() g)
  );

DROP POLICY IF EXISTS "Authenticated users can upload chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Members can upload chat attachments" ON storage.objects;
CREATE POLICY "Members can upload chat attachments" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'chat-attachments'
    AND (storage.foldername(name))[1] IN (SELECT g::text FROM public.get_my_group_ids() g)
  );

-- Avatars stay publicly viewable, but you can only write {your_user_id}/...
DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
CREATE POLICY "Users can upload own avatar" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can update own avatar" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)
  WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Group photos stay publicly viewable, but only the group creator can write
-- {group_id}/... (same rule as updating groups.photo_url).
DROP POLICY IF EXISTS "Members can upload group photo" ON storage.objects;
CREATE POLICY "Members can upload group photo" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'group-photos'
    AND (storage.foldername(name))[1] IN
        (SELECT id::text FROM public.groups WHERE created_by = auth.uid())
  );

DROP POLICY IF EXISTS "Members can update group photo" ON storage.objects;
CREATE POLICY "Members can update group photo" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'group-photos'
    AND (storage.foldername(name))[1] IN
        (SELECT id::text FROM public.groups WHERE created_by = auth.uid())
  )
  WITH CHECK (
    bucket_id = 'group-photos'
    AND (storage.foldername(name))[1] IN
        (SELECT id::text FROM public.groups WHERE created_by = auth.uid())
  );
