-- ============================================================================
-- Indexes from APP_REVIEW.md §6 that did not exist yet.
--
-- Already there (not repeated): expense_splits(expense_id),
-- expense_splits(user_id), notifications(user_id, created_at),
-- group_members(group_id, user_id) (its UNIQUE key also covers group_id).
-- expense_splits(user_id, is_settled) is not added: since the money ledger
-- (20261027140000) is_settled is not used for balances any more.
--
-- IF NOT EXISTS → safe to run more than once. The tables are small, so a
-- normal CREATE INDEX (a few milliseconds of write lock) is fine.
-- ============================================================================

-- "Which groups am I in?" — every groups list, RLS helper and get_my_debts
CREATE INDEX IF NOT EXISTS group_members_user_id_idx
  ON public.group_members (user_id);

-- A group's expenses, newest first
CREATE INDEX IF NOT EXISTS expenses_group_id_created_at_idx
  ON public.expenses (group_id, created_at DESC);

-- Chat: newest 50 messages of a group, then the 50 before them
CREATE INDEX IF NOT EXISTS messages_group_id_created_at_idx
  ON public.messages (group_id, created_at DESC);
