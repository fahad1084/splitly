#!/usr/bin/env bash
# ============================================================================
# Concurrency test for the per-group lock in record_settlement
# (supabase/migrations/20261027140000_money_ledger.sql).
#
# LOCAL DATABASE ONLY — it creates fake users (kashif@ / laila@test.local).
#   supabase start
#   supabase db reset
#   bash supabase/tests/concurrency_test.sh
#   supabase stop
#
# Kashif owes Laila 100. TWO database connections record a payment of 70 at
# the same moment (together 140 — more than is owed).
#   Session 1 records 70 and keeps its transaction open for 3 seconds.
#   Session 2 starts 1 second later and also records 70.
# Expected: session 2 WAITS for session 1, then sees the 70 already pending
# and fails with AMOUNT_TOO_HIGH. Without the lock, both would succeed.
# ============================================================================
set -u
DB="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
K='e1000000-0000-0000-0000-0000000000e1'   # Kashif (owes)
L='f1000000-0000-0000-0000-0000000000f1'   # Laila (is owed)
G='93000000-0000-0000-0000-000000000093'
TMP="$(dirname "$0")/../../.tmp"   # the project's .tmp/ (git-ignored)
mkdir -p "$TMP"
AS_KASHIF="set local role authenticated; select set_config('request.jwt.claims', '{\"sub\":\"$K\",\"role\":\"authenticated\"}', true);"

psql "$DB" -q -v ON_ERROR_STOP=1 > /dev/null <<SQL
insert into auth.users (id, email, aud, role) values
  ('$K', 'kashif@test.local', 'authenticated', 'authenticated'),
  ('$L', 'laila@test.local', 'authenticated', 'authenticated') on conflict do nothing;
insert into public.profiles (id, full_name) values ('$K', 'Kashif'), ('$L', 'Laila') on conflict do nothing;
insert into public.groups (id, name, currency, created_by) values ('$G', 'Race test', 'PKR', '$L') on conflict do nothing;
insert into public.group_members (group_id, user_id, role) values ('$G', '$L', 'admin'), ('$G', '$K', 'member') on conflict do nothing;
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"$L","role":"authenticated"}', true);
select public.add_expense('$G', '$L', 'Rent share', 200, jsonb_build_array(
  jsonb_build_object('user_id', '$K', 'amount_owed', 100),
  jsonb_build_object('user_id', '$L', 'amount_owed', 100)));
commit;
SQL

echo "== Kashif owes Laila (expect 100.00):"
psql "$DB" -tA -c "select amount from public.group_debts('$G')"

echo "== Session 1: record 70, hold the transaction for 3 seconds ..."
psql "$DB" -tA -c "begin; $AS_KASHIF select 'session 1 OK: ' || public.record_settlement('$G', '$K', '$L', 70); select pg_sleep(3); commit;" \
  > "$TMP/splitly_s1.txt" 2>&1 &
S1=$!
sleep 1
echo "== Session 2 (1 second later): record 70 at the same time ..."
START=$(date +%s)
psql "$DB" -tA -c "begin; $AS_KASHIF select 'session 2 OK: ' || public.record_settlement('$G', '$K', '$L', 70); commit;" \
  > "$TMP/splitly_s2.txt" 2>&1
END=$(date +%s)
wait $S1

echo "-- session 1:"; grep -E "OK|ERROR" "$TMP/splitly_s1.txt"
echo "-- session 2 (waited ~$((END - START))s for session 1):"; grep -E "OK|ERROR" "$TMP/splitly_s2.txt"
echo "== Pending total (expect 70.00 — only ONE payment got in):"
psql "$DB" -tA -c "select sum(amount) from public.settlements where group_id = '$G' and status = 'pending'"
rm -f "$TMP/splitly_s1.txt" "$TMP/splitly_s2.txt"
