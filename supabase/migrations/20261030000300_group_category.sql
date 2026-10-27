-- ============================================================================
-- Splitly — save the group type (APP_REVIEW.md fix #10, step 10d)
--
-- groups.category already existed (default 'Other') but create_group()
-- never saved the choice. Now:
--   * create_group(..., p_category) saves it. Old app versions don't send
--     it and get 'other'.
--   * One spelling: home, trip, friends, office, family, other. Existing
--     values are lower-cased; anything unknown becomes 'other'.
--
-- Safe on a database with data and safe to run twice.
-- ============================================================================


-- ── 1. One spelling for the existing rows, then a check ─────────────────────
UPDATE public.groups
   SET category = CASE
         WHEN lower(category) IN ('home', 'trip', 'friends', 'office', 'family', 'other')
           THEN lower(category)
         ELSE 'other'
       END
 WHERE category IS NULL
    OR category NOT IN ('home', 'trip', 'friends', 'office', 'family', 'other');

ALTER TABLE public.groups ALTER COLUMN category SET DEFAULT 'other';
ALTER TABLE public.groups ALTER COLUMN category SET NOT NULL;

ALTER TABLE public.groups DROP CONSTRAINT IF EXISTS groups_category_check;
ALTER TABLE public.groups
  ADD CONSTRAINT groups_category_check
  CHECK (category IN ('home', 'trip', 'friends', 'office', 'family', 'other'));


-- ── 2. create_group with the type ───────────────────────────────────────────
-- Same as 20261027130000_transactions.sql plus p_category. The old
-- 3-argument version is dropped so calls are never ambiguous.
DROP FUNCTION IF EXISTS public.create_group(text, text, text);

CREATE OR REPLACE FUNCTION public.create_group(
  p_name text,
  p_description text DEFAULT NULL,
  p_currency text DEFAULT 'PKR',
  p_category text DEFAULT 'other'
)
RETURNS uuid
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public
AS $$
declare
  v_uid uuid := auth.uid();
  v_id uuid := gen_random_uuid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_name is null or length(trim(p_name)) < 2 then
    raise exception 'INVALID_NAME';
  end if;

  insert into public.groups (id, name, description, currency, created_by, category)
  values (
    v_id,
    trim(p_name),
    nullif(trim(coalesce(p_description, '')), ''),
    coalesce(nullif(trim(p_currency), ''), 'PKR'),
    v_uid,
    case when lower(p_category) in ('home', 'trip', 'friends', 'office', 'family')
         then lower(p_category) else 'other' end
  );

  insert into public.group_members (group_id, user_id, role)
  values (v_id, v_uid, 'admin');

  return v_id;
end;
$$;
