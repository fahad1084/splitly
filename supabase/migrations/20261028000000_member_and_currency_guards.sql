-- ============================================================================
-- Splitly — member and currency guards
--
-- 1. remove_member(group, user): an admin (or the creator) removing someone
--    is BLOCKED while that person still owes or is owed money in the group
--    (same rule as leave_group). The direct DELETE policy is dropped, so this
--    function is the only way to remove someone.
-- 2. A group's currency can no longer change once it has expenses or
--    payments — otherwise old amounts would silently switch currency.
--    (Settlements and expenses already always take the group's currency.)
--
-- Error codes: NOT_ALLOWED, NOT_A_MEMBER, HAS_UNSETTLED_DEBTS, CURRENCY_LOCKED
--
-- Safe on a database with data and safe to run twice: CREATE OR REPLACE,
-- DROP ... IF EXISTS + CREATE, no rows are changed. No REVOKE EXECUTE
-- (see 20261027120000_security_fixes.sql §5).
-- ============================================================================


-- ── 1. remove_member ────────────────────────────────────────────────────────
-- Same permission as before (the group creator or an admin), plus the
-- debt check. Uses the same per-group lock as the settlement functions, so
-- a payment recorded at the same moment can't slip past the check.
CREATE OR REPLACE FUNCTION public.remove_member(p_group_id uuid, p_user_id uuid)
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
  if not (public.is_group_creator(p_group_id) or public.is_group_admin(p_group_id)) then
    raise exception 'NOT_ALLOWED';
  end if;
  if not public.is_group_member(p_group_id, p_user_id) then
    raise exception 'NOT_A_MEMBER';
  end if;

  perform pg_advisory_xact_lock(hashtext('settle:' || p_group_id::text));
  if exists (
    select 1 from public.group_debts(p_group_id) d
     where d.debtor_id = p_user_id or d.creditor_id = p_user_id
  ) then
    raise exception 'HAS_UNSETTLED_DEBTS';
  end if;

  delete from public.group_members
   where group_id = p_group_id and user_id = p_user_id;
end;
$$;

-- Removing someone now only works through remove_member() (and leaving
-- only through leave_group()), so nobody can drop a member with debts.
DROP POLICY IF EXISTS "Admins can remove members" ON public.group_members;


-- ── 2. Lock the group currency once money is recorded ───────────────────────
CREATE OR REPLACE FUNCTION public._block_currency_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
begin
  if new.currency is distinct from old.currency and (
       exists (select 1 from public.expenses where group_id = old.id)
    or exists (select 1 from public.settlements where group_id = old.id)
  ) then
    raise exception 'CURRENCY_LOCKED';
  end if;
  return new;
end;
$$;

DROP TRIGGER IF EXISTS groups_block_currency_change ON public.groups;
CREATE TRIGGER groups_block_currency_change
  BEFORE UPDATE OF currency ON public.groups
  FOR EACH ROW EXECUTE FUNCTION public._block_currency_change();
