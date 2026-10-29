#!/usr/bin/env bash
# ============================================================================
# Race test: deleting an expense while a payment is being confirmed
# (delete_expense takes the same per-group lock as confirm_settlement —
# supabase/migrations/20261031000000_phase4_fixes.sql).
#
# LOCAL DATABASE ONLY — it creates fake users (karim@ / lubna@test.local).
#   supabase start
#   supabase db reset
#   bash supabase/tests/delete_confirm_race_test.sh
#   supabase stop
#
# Lubna paid Rent 200 (Karim 100 / Lubna 100) and Water 100 (Karim 50 /
# Lubna 50), so Karim owes Lubna 150. Karim records "I paid 150" (pending).
#
# A) Delete first: session 1 (Lubna) deletes Water and holds its transaction
#    for 3 s; session 2 (Lubna) confirms the 150 one second later.
#    Expected: session 2 WAITS, then sees the debt is only 100 and fails with
#    AMOUNT_TOO_HIGH. Without the lock it would confirm 150 against a debt
#    of 100, and Lubna would wrongly owe Karim 50.
# B) Confirm first: session 1 confirms and holds 3 s; session 2 deletes
#    Water one second later. Expected: the delete WAITS, then runs. Karim
#    paid 150 for a debt that is now 100, so Lubna owes Karim 50 — correct
#    ledger math (the app warns before deleting an expense with payments).
# ============================================================================
set -u
DB="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
TMP="$(dirname "$0")/../../.tmp"   # the project's .tmp/ (git-ignored)
mkdir -p "$TMP"
K='e2000000-0000-0000-0000-0000000000e2'   # Karim (owes)
L='f2000000-0000-0000-0000-0000000000f2'   # Lubna (is owed)
AS_K="set local role authenticated; select set_config('request.jwt.claims', '{\"sub\":\"$K\",\"role\":\"authenticated\"}', true);"
AS_L="set local role authenticated; select set_config('request.jwt.claims', '{\"sub\":\"$L\",\"role\":\"authenticated\"}', true);"

psql "$DB" -q -v ON_ERROR_STOP=1 > /dev/null <<SQL
insert into auth.users (id, email, aud, role) values
  ('$K', 'karim@test.local', 'authenticated', 'authenticated'),
  ('$L', 'lubna@test.local', 'authenticated', 'authenticated') on conflict do nothing;
insert into public.profiles (id, full_name) values ('$K', 'Karim'), ('$L', 'Lubna') on conflict do nothing;
SQL

# One group per scenario: Rent + Water paid by Lubna, Karim's 150 pending.
# Prints the id of the Water expense and of the pending payment.
setup() {
  local G="$1"
  psql "$DB" -q -v ON_ERROR_STOP=1 > /dev/null <<SQL
insert into public.groups (id, name, currency, created_by) values ('$G', 'Race test', 'PKR', '$L');
insert into public.group_members (group_id, user_id, role) values ('$G', '$L', 'admin'), ('$G', '$K', 'member');
SQL
  local water
  water=$(psql "$DB" -tA -v ON_ERROR_STOP=1 -c "begin; $AS_L
    select public.add_expense('$G', '$L', 'Rent', 200, jsonb_build_array(
      jsonb_build_object('user_id', '$K', 'amount_owed', 100),
      jsonb_build_object('user_id', '$L', 'amount_owed', 100)));
    select public.add_expense('$G', '$L', 'Water', 100, jsonb_build_array(
      jsonb_build_object('user_id', '$K', 'amount_owed', 50),
      jsonb_build_object('user_id', '$L', 'amount_owed', 50)));
    commit;" | sed -n 3p)
  local pay
  pay=$(psql "$DB" -tA -v ON_ERROR_STOP=1 -c "begin; $AS_K
    select public.record_settlement('$G', '$K', '$L', 150); commit;" | sed -n 2p)
  echo "$water $pay"
}

debts() {
  psql "$DB" -tA -c "select p1.full_name || ' owes ' || p2.full_name || ' ' || d.amount
    from public.group_debts('$1') d join public.profiles p1 on p1.id = d.debtor_id
    join public.profiles p2 on p2.id = d.creditor_id"
}

echo "=================== A) delete first, confirm 1 s later ==================="
GA='96000000-0000-0000-0000-0000000000a6'
read -r WATER PAY <<< "$(setup "$GA")"
echo "== Before (expect Karim owes Lubna 150.00):"; debts "$GA"
psql "$DB" -tA -c "begin; $AS_L select 'session 1 deleted Water'; select public.delete_expense('$WATER'); select pg_sleep(3); commit;" \
  > "$TMP/race_a1.txt" 2>&1 &
S1=$!
sleep 1
START=$(date +%s)
psql "$DB" -tA -c "begin; $AS_L select public.confirm_settlement('$PAY'); select 'session 2 confirmed'; commit;" \
  > "$TMP/race_a2.txt" 2>&1
END=$(date +%s)
wait $S1
echo "-- session 1:"; grep -E "deleted|ERROR" "$TMP/race_a1.txt"
echo "-- session 2 (waited ~$((END - START))s; expect ERROR AMOUNT_TOO_HIGH):"; grep -E "confirmed|ERROR" "$TMP/race_a2.txt"
echo "== After (expect Karim owes Lubna 100.00, the payment still pending):"; debts "$GA"
psql "$DB" -tA -c "select 'payment status: ' || status from public.settlements where id = '$PAY'"

echo "=================== B) confirm first, delete 1 s later ==================="
GB='96000000-0000-0000-0000-0000000000b6'
read -r WATER PAY <<< "$(setup "$GB")"
psql "$DB" -tA -c "begin; $AS_L select public.confirm_settlement('$PAY'); select 'session 1 confirmed'; select pg_sleep(3); commit;" \
  > "$TMP/race_b1.txt" 2>&1 &
S1=$!
sleep 1
START=$(date +%s)
psql "$DB" -tA -c "begin; $AS_L select public.delete_expense('$WATER'); select 'session 2 deleted Water'; commit;" \
  > "$TMP/race_b2.txt" 2>&1
END=$(date +%s)
wait $S1
echo "-- session 1:"; grep -E "confirmed|ERROR" "$TMP/race_b1.txt"
echo "-- session 2 (waited ~$((END - START))s; expect: deleted Water):"; grep -E "deleted|ERROR" "$TMP/race_b2.txt"
echo "== After (expect Lubna owes Karim 50.00):"; debts "$GB"

rm -f "$TMP"/race_*.txt
