# Splitly backend (Supabase)

Everything the Flutter app needs on the server side is in this folder.

| Path | What it is |
|---|---|
| `migrations/20261027000000_remote_schema.sql` | Baseline: all `public` tables, constraints, indexes, RPC functions, RLS policies, grants, realtime publication. Exported from the live project on 2026-10-27. |
| `migrations/20261027000100_storage_buckets.sql` | Storage buckets (`avatars`, `group-photos`, `chat-attachments`) and their access policies. Safe to run more than once. |
| `migrations/<later>_*.sql` | Every later database change, one file each, applied in name order. |
| `setup/webhooks_and_cron.sql` | The 4 Database Webhooks and 2 cron jobs. **Template with placeholders — run by hand, never commit a filled-in copy.** |
| `functions/send-push-notification/` | Edge Function: push notifications for new messages, expenses, settlements, members. Called by the webhooks. |
| `functions/send-debt-reminders/` | Edge Function: daily "you still owe X" reminders. Called by cron. |
| `config.toml` | Supabase CLI settings (local dev + function settings such as `verify_jwt = false`). |

### What the database contains

- **Tables:** `profiles`, `groups`, `group_members`, `expenses`, `expense_splits`, `settlements`, `messages`, `typing_status`, `chat_read_status`, `notifications`, `debt_reminders_sent`
- **RPC functions called by the app:**
  - groups: `create_group`, `join_group_by_code`, `leave_group`, `remove_member`, `delete_group_permanently`
  - expenses: `add_expense`, `delete_expense`
  - money: `get_my_debts`, `record_settlement`, `confirm_settlement`, `cancel_settlement`
  - other: `get_unread_counts`, `delete_own_account`, `get_group_preview_by_invite_code` (old, not used any more)
- **The balance math (the only copy):** `group_debts(group_id)`. Balance between two people = their expense splits − their **confirmed** settlements. `expense_splits.is_settled` is not used for money any more.
- **For the reminder Edge Function only:** `debts_for_reminders` (service role).
- **Helper functions used by RLS:** `get_my_group_ids`, `is_group_member`, `is_group_admin`, `is_group_creator`, `is_authenticated`
- **Cron function:** `generate_recurring_expenses`, which creates the next copy of each recurring expense once a day.
- **No `REVOKE EXECUTE`.** On this Postgres version, a "permission denied for function" error crashes the database server, so every function checks its caller itself.

### Tests (local database only)

- `tests/security_attacks.sql`: attack and "normal use" checks for RLS and the RPCs.
- `tests/money_tests.sql`: balances, partial payments, pending/confirm/cancel, leaving or removing members with debts, currency, exact splits.
- `tests/concurrency_test.sh`: 2 payments at the same moment, which proves the lock in `record_settlement`. Run it with `bash`, not `psql`.

Each file needs a **fresh** local database. Run these one at a time:

```bash
supabase start
```

```bash
supabase db reset
```

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/tests/money_tests.sql
```

Run `supabase db reset` again before the other test file. When you're done:

```bash
supabase stop
```

### Known gaps / TODO

- [ ] **Push notifications for confirm and cancel of a payment.** Today:
  - `record_settlement` → **push** (through the `notify-new-settlement` webhook, which fires on INSERT only)
  - `confirm_settlement` / `cancel_settlement` → **in-app notification only** (they write to `notifications` themselves)

  **To add the push:**
  1. Add an **UPDATE** webhook on `settlements` to `setup/webhooks_and_cron.sql`. Fire it only when `status` changes from `pending` to `confirmed` or `cancelled`.
  2. In `functions/send-push-notification`, handle `payload.type === "UPDATE"` (`payload.old_record` and `payload.record`). Send to the other person: the payer when it's confirmed, the other side when it's cancelled.
  3. Remove the `_notify_settlement(...)` calls from the 2 RPCs, so nobody gets 2 notifications.

---

## A. Set up a NEW Supabase project from these files

You need: the [Supabase CLI](https://supabase.com/docs/guides/cli), a Supabase account, and the Firebase service-account JSON for push notifications.

1. **Create the project** in the Supabase Dashboard. Write down:
   - the **project ref** (Project Settings → General)
   - the **database password**

2. **Link the CLI to it.** Run these from the repo root:
   ```bash
   supabase login
   supabase link --project-ref <NEW_PROJECT_REF>
   ```

3. **Create the database.** This runs every file in `migrations/`, in order:
   ```bash
   supabase db push
   ```

4. **Set the Edge Function secrets.** Use values from your Firebase service-account JSON. Make up a long random `WEBHOOK_SECRET`:
   ```bash
   supabase secrets set FIREBASE_PROJECT_ID=<firebase-project-id>
   supabase secrets set FIREBASE_CLIENT_EMAIL=<client_email from the JSON>
   supabase secrets set FIREBASE_PRIVATE_KEY="<private_key from the JSON, with \n kept>"
   supabase secrets set WEBHOOK_SECRET=<long-random-string>
   ```
   `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are set by Supabase automatically.

5. **Deploy the Edge Functions.** `config.toml` keeps `verify_jwt = false` for both:
   ```bash
   supabase functions deploy send-push-notification
   supabase functions deploy send-debt-reminders
   ```

6. **Create the webhooks and cron jobs.** Open `setup/webhooks_and_cron.sql`, copy it, and replace `<PROJECT_REF>` and `<WEBHOOK_SECRET>`. Use the same secret as step 4. Run it in **Dashboard → SQL Editor**. Don't save the filled-in copy in the repo.

7. **Auth settings.** These are not stored in SQL, so set them in the Dashboard:
   - **Authentication → URL Configuration**
     - Site URL: `com.splitly.app://callback`
     - Redirect URLs: add `com.splitly.app://callback`. This is used for email confirmation and password reset.
   - **Authentication → Sign In / Providers**
     - Email: enabled. Choose whether "Confirm email" is on.
     - Google: enabled. Client ID = the **Web** client ID from Google Cloud Console (the same one as `webClientId` in `lib/features/auth/controllers/auth_controller.dart`), plus its client secret. Also add the Android client ID to "Authorized Client IDs".
   - **Authentication → Emails → SMTP:** for real users, set up your own SMTP (Resend, SendGrid, Amazon SES…). The built-in mailer only sends a few emails per hour.
   - **Authentication → Sessions / JWT expiry:** `3600` seconds, which is the default.

8. **Point the app at the new project.** Copy `.env.example` (in the repo root) to `.env` and fill in the new project's URL and anon key (Project Settings → API).

9. **Smoke test:** sign up, create a group, add an expense, send a chat message, and check that a push arrives on a second phone.

---

## B. The LIVE project (`splitly`, ref `cnujujebhebvfzvyenpn`)

The live project **already has** everything in the two baseline files. **Never run them on it.** Mark them as already applied, one time only:

```bash
supabase link --project-ref cnujujebhebvfzvyenpn
supabase migration repair --status applied 20261027000000 20261027000100
supabase migration list
```

`migration list` should show both versions under **Local** and **Remote**. After this, `supabase db push` only sends **new** migrations.

### Adding a database change later

1. Create a new file, for example:
   ```bash
   supabase migration new short_name
   ```
   This creates `migrations/<timestamp>_short_name.sql`.
2. Write SQL that is safe on a database that already has data: `IF NOT EXISTS`, `DROP POLICY IF EXISTS` + `CREATE POLICY`, `ON CONFLICT DO NOTHING`, and so on.
3. **Test it on a test project first.** Link the test project, run `supabase db push`, and test the app against it.
4. Then link the live project and run `supabase db push`.

---

## C. Re-export from the live project

Use this if someone changed the database in the Dashboard and you want to see what changed:

```bash
supabase db dump --linked -f /tmp/live_schema.sql          # public schema (needs Docker running)
supabase db query --linked "select jobname, schedule from cron.job"
```

`supabase db dump` misses cron jobs: the `cron.job` table hides rows from other database users. That's why the query above lists them separately. Compare the dump with the migrations, and put any difference into a new migration.
