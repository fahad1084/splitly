# Splitly — Independent App Review

**Reviewed:** 27 Oct 2026 · **Scope:** the whole repo (`lib/`, `android/`, `ios/`, `supabase/functions/`, config files) at commit `7cf3a8a` plus the uncommitted changes in the working tree. **Method:** read-only. I read the code and traced each flow. I did not run the app, build it, or connect to the Supabase project.

> **One important limitation.** The repo has **no SQL files at all**. There are no migrations, no RLS policies, no RPC function code, and no triggers. The app calls RPCs that are not in the repo (`delete_own_account`, `delete_group_permanently`, `get_unread_counts`, `get_group_preview_by_invite_code`). A comment also mentions a `debt_reminders_migration.sql` file that is missing (`supabase/functions/send-debt-reminders/index.ts:3`). So **I could not check database security or schema**. Everything I say about RLS is about what the app *relies on*, not what is really deployed.

---

## 1. What the app is

### In plain words
Splitly is a **bill-splitting app for friends, flatmates and families**, similar in idea to Splitwise, made for **Pakistan**. The default currency is PKR, there are "Ration" and "Rent" categories, the tagline is "Your Hisaab", and the app is translated into English and Urdu. People make a **group**, invite others with a **code or QR**, add **shared expenses**, see **who owes whom**, and **settle up**. Each group also has a **chat**.

### Features that work (based on the code)

| Feature | Status | Where |
|---|---|---|
| Email sign up / sign in / forgot + reset password | ✅ Works | `auth_controller.dart:47-212`, `main.dart:156-190` |
| Google Sign-In | ✅ Works (Android) | `auth_controller.dart:125-191` |
| Onboarding slides (first launch only) | ✅ Works | `onboarding_screen.dart`, `main.dart:224-226` |
| Create group (name, description, currency) | ✅ Works | `groups_controller.dart:132-175` |
| Join group by invite code / QR scan | ✅ Works | `join_group_screen.dart:20-71` |
| Members: make admin, remove member, leave group | ✅ Works (see security notes) | `groups_controller.dart:214-261`, `group_detail_screen.dart:1075-1180` |
| Group photo, profile photo (with cropping) | ✅ Works | `groups_controller.dart:263-283`, `edit_profile_screen.dart:120-150` |
| Archive / unarchive / permanently delete group | ✅ Works | `groups_controller.dart:177-202`, `archived_groups_screen.dart` |
| Add expense with **equal / custom / percentage** split | ✅ Works (rounding issues, §4) | `expenses_controller.dart:71-223`, `add_expense_sheet.dart:127-197` |
| Delete expense (only the payer sees the button) | ✅ Works | `expense_detail_sheet.dart:282-315` |
| Per-group and overall balances, pairwise "who owes who" | ⚠️ Works, but has bugs (§4) | `balances_controller.dart` |
| Settle up | ⚠️ Works, but the math is wrong in common cases (§4) | `balances_controller.dart:198-249` |
| Group chat: text, replies, @mentions, images, voice notes, typing indicator, unread badges | ✅ Works, with limits (§4, §6) | `chat_controller.dart`, `chat_screen.dart` |
| Receipt scanning (on-device ML Kit OCR fills in the amount) | ✅ Works, but simple | `receipt_scanner_screen.dart` |
| Export to PDF / CSV, share a text summary | ✅ Works (PDF fonts issue, §3) | `export_service.dart`, `share_summary_sheet.dart` |
| Spending reports with charts (week / month / all) | ✅ Works | `reports_screen.dart` |
| Push notifications (new message, expense, settlement, member) + in-app notification inbox + per-type mute settings | ✅ Works (Android) | `supabase/functions/send-push-notification`, `notifications_controller.dart` |
| Daily debt reminders | ✅ Code exists, server cron not in repo | `supabase/functions/send-debt-reminders` |
| App lock: 4-digit PIN + fingerprint | ⚠️ Works, but weak (§5) | `app_lock_controller.dart`, `main.dart:80-123` |
| English / Urdu language switch | ✅ Works | `locale_controller.dart`, `lib/l10n/` |
| Light / dark theme (follows the system) | ✅ Works | `main.dart:50-52` |
| Delete account (anonymize) | ✅ Client side works; the RPC is not in the repo | `auth_controller.dart:227-245` |
| Android home-screen balance widget | 🟡 New, uncommitted | `home_widget_service.dart`, `SplitlyWidgetProvider.kt` |

### Half-built, unused, or only partly connected

- **Recurring expenses do nothing.** You can switch on "recurring" and choose daily/weekly/monthly. The app saves `is_recurring` and `next_recur_at` (`expenses_controller.dart:94-124`). But **no code anywhere creates the next expense**. There is no Edge Function and no cron job in the repo. Users will think it works and it won't.
- **Group type/category is ignored.** The create-group sheet shows a type picker (`create_group_sheet.dart:19, 50, 154`), but `createGroup()` has no `category` parameter, so the choice is never saved (`groups_controller.dart:132-175`).
- **Receipt images are never stored.** `ExpenseModel` has `receiptUrl` (`expense_model.dart`), but nothing ever writes `receipt_url`. The privacy policy says the image "may be stored" (`privacy-policy.html:123`).
- **Tapping a push notification does nothing.** `// TODO: navigate to relevant screen` (`fcm_service.dart:111-115`).
- **No settlement history screen.** Settlements are saved to a `settlements` table, but the only place they are read is the notification detail sheet (`notification_detail_sheet.dart:76`).
- **No edit expense.** You can only delete and re-create. There is also **no way to pick an expense date**: the date is always `created_at`, so you can't log yesterday's dinner with yesterday's date.
- **iOS doesn't work at all** (see §8). The app throws at startup on iOS (`firebase_options.dart:28-32`).
- **Dead code:**
  - `lib/features/auth/screens/balances_tab.dart`: an old placeholder, not imported anywhere.
  - `lib/config/router/app_router.dart` and `lib/core/constants/app_constants.dart`: empty files (0 lines).
  - `groupBalancesProvider` (`expenses_controller.dart:227-255`): a second balance calculation that nothing uses.
- **Unused packages:** `go_router`, `cached_network_image`, `flutter_svg`, `timeago` (no imports in `lib/`).

---

## 2. How it's built

### Folder structure
```
lib/
  main.dart                  ← app start, AuthGate, app-lock wrapper, splash routing
  config/   supabase/ theme/ router/(empty)
  core/     widgets/shared_widgets.dart, utils/, services/home_widget_service.dart
  features/<feature>/{controllers, models, screens}
     auth, groups, expenses, balances, chat, notifications, reports,
     security, settings, onboarding
  l10n/                      ← ARB files + generated localizations (en, ur)
supabase/functions/          ← 2 Deno Edge Functions (push + reminders)
```
This is a normal **feature-first** layout and it is easy to find things. Some files are in the wrong folder:
- `edit_profile_screen.dart` is in `groups/`.
- `export_service.dart` (not a screen) is in `expenses/screens/`.
- `JoinGroupController` lives inside a screen file (`join_group_screen.dart:16`).

### Architecture and data flow
```
Widget (ConsumerWidget / ConsumerStatefulWidget)
   │ ref.watch(provider)  /  ref.read(provider.notifier).method()
   ▼
Riverpod provider (AsyncNotifier, StateNotifier, FutureProvider, or plain static class)
   │ SupabaseConfig.client.from('table')...   ← direct PostgREST calls, no repository layer
   ▼
Supabase (Postgres + RLS + Storage + Realtime)
   │ Database Webhooks on INSERT
   ▼
Edge Function send-push-notification → FCM v1 → device → flutter_local_notifications
```
- **Reading:** for example, `groupsProvider.build()` runs 3 queries: memberships, then groups, then all member rows to count them (`groups_controller.dart:75-130`). `expensesProvider(groupId)` loads **every expense with its splits**, then one query for names (`expenses_controller.dart:21-68`).
- **Writing:** the controller inserts, then **re-fetches the whole list** and replaces the state (for example `expenses_controller.dart:129`).
- **Balances are computed on the phone** from the full expense list (`balances_controller.dart:57-186`). The server never stores a balance.
- **Realtime** is used only for chat messages (`chat_controller.dart:114-157`) and the typing indicator (`typing_status` stream). Expenses and balances **do not update live**. You must pull to refresh or reopen the screen.
- **Mixed patterns:** `AsyncNotifier` (groups, expenses, chat), `StateNotifier` (auth, settle, lock), plain `FutureProvider`s, and a static class (`NotificationsController`). Some widgets call Supabase directly (`edit_profile_screen.dart:51, 128-170`).
- **Navigation** is plain `Navigator.push` with one global `navigatorKey` (`main.dart:25`). `go_router` is in pubspec but not used.

### Database tables I can infer from the code

| Table | Columns used | Relationships |
|---|---|---|
| `profiles` | id, full_name, avatar_color, avatar_url, phone, fcm_token, notify_messages/expenses/settlements/members/debt_reminders | id = auth.users.id |
| `groups` | id, name, description, currency, created_by, invite_code, is_archived, category(?), photo_url, created_at | created_by → profiles |
| `group_members` | id, group_id, user_id, role ('admin'/'member') | → groups, → profiles (join used at `groups_controller.dart:318`) |
| `expenses` | id, group_id, paid_by, title, amount, currency, category, split_type, notes, receipt_url, is_recurring, recur_every, next_recur_at, created_at | → groups, paid_by → profiles |
| `expense_splits` | id, expense_id, user_id, amount_owed, is_settled, settled_at | → expenses, → profiles |
| `settlements` | id, group_id, paid_by, paid_to, amount, currency | → groups, → profiles (×2) |
| `messages` | id, group_id, sender_id, content, reply_to_id, attachment_url, attachment_type, audio_duration, created_at | → groups, → profiles, self-ref reply |
| `typing_status` | group_id, user_id (PK pair), user_name, updated_at | |
| `chat_read_status` | group_id, user_id, last_read_at | |
| `notifications` | id, user_id, type, title, body, group_id, entity_id, read_at, created_at | |
| `debt_reminders_sent` | group_id, debtor_id, creditor_id, last_reminded_at | used by Edge Function |
| Storage buckets | `avatars`, `group-photos`, `chat-attachments` (all used with `getPublicUrl`) | |

I can't confirm column types, indexes, unique constraints, or foreign-key `ON DELETE` rules, because the schema is not in the repo.

### Third-party packages

| Package | Used for | Notes |
|---|---|---|
| supabase_flutter 2.15 | backend | OK |
| firebase_core / firebase_messaging | push | OK, Android only is configured |
| flutter_riverpod 2.6 | state | OK. Riverpod 3 exists, but 2.x is fine |
| flutter_local_notifications 17 | shows the push notifications | Older major version (newer majors exist) |
| google_sign_in 6.3 | Google login | v7 changed the API. Fine for now |
| local_auth 2.3, crypto | app lock | PIN hash is weak (§5) |
| shared_preferences | PIN hash, flags, locale, onboarding | Not secure storage |
| google_mlkit_text_recognition | receipt OCR | **Android Gradle also adds Chinese, Japanese, Korean and Devanagari models** (`build.gradle.kts:39-43`). That makes the APK much bigger for no reason |
| image_picker, image_cropper | photos | OK |
| record 5.0.4 (pinned) + 2 `dependency_overrides` | voice notes | Pinned with overrides, a fragile setup |
| audioplayers | play voice notes | OK |
| pdf, printing, csv, share_plus, path_provider | export | PDF has no Unicode font (§3) |
| fl_chart | reports | OK |
| qr_flutter, mobile_scanner 5 | invite QR | mobile_scanner 6/7 exist |
| home_widget | Android widget | new |
| flutter_dotenv | loads `.env` | `.env` is **bundled into the APK as an asset** (`pubspec.yaml:58`). OK for the anon key, but never put a secret there. There is no `.env.example` |
| uuid, intl, google_fonts, shimmer | misc | OK |
| **go_router, cached_network_image, flutter_svg, timeago** | **unused** | remove |
| flutter_launcher_icons | dev | OK |

---

## 3. How easy it is to use (UX)

### First-time user walkthrough
1. **Every** app start waits a fixed **2 seconds** on the splash screen, even when everything is ready (`main.dart:215`).
2. Onboarding slides, then sign up. After email sign-up, Supabase may need email confirmation. The user goes back to login, which is OK.
3. **Empty Groups tab**, with a create-group FAB and a join option. Good.
4. Create a group. The **group type picker looks important but does nothing** (§1).
5. Invite friends with a code, QR or share sheet. Clear and nice.
6. Add an expense. The form is clear. The equal-split preview updates as you type. Custom and percentage splits are checked before saving. Good.
7. Open Balances and tap a debt to settle. It only allows **settling the full amount**. There is no partial payment, no note, and no "cash / JazzCash / bank" choice.

**Where people get confused or stuck:**
- **Kicked back to the home screen about once an hour.** `AuthGate` treats `tokenRefreshed` like a new login and calls `pushAndRemoveUntil(HomeScreen)` (`main.dart:163-167`). Supabase refreshes the token about every hour. So a user who is in the middle of a chat or the add-expense form is suddenly sent back to Home and **loses what they typed**. If app lock is on, they also get the PIN screen again (`_AppLockWrapper` is created fresh and calls `_checkLockOnStart`). This is the biggest UX bug.
- **Raw technical errors are shown to users.** Messages like `Error: PostgrestException(message: ..., code: 42501...)` go straight into a snackbar (`groups_controller.dart:173`, `expenses_controller.dart:133`, `balances_controller.dart:247`, `join_group_screen.dart:69`).
- **Errors that look like "empty".** Chat fetch errors return `[]` (`chat_controller.dart:108-111`), so a network error looks like "no messages yet". Notifications, unread counts and archived groups do the same.
- **The "recurring" switch does nothing** (§1).
- **Totals mix currencies** (§4). A user with a PKR group and a USD group sees nonsense totals.
- **Amounts are rounded to whole numbers on screen** in 33 places (`toStringAsFixed(0)`), for example in the settle sheet (`settle_up_sheet.dart:202`), the PDF (`export_service.dart:48, 75`) and the widget. The real debt is PKR 333.33, but the screen says "PKR 333". The receipt scanner also cuts off the decimals when it fills the amount (`add_expense_sheet.dart:350-351`).
- **Any member can archive a group for everyone.** There's no admin check in the menu (`group_detail_screen.dart:716-728`). "Leave group" is a red option placed between "Export" and "Reports", so it's easy to mis-tap. The app also lets you leave **with unpaid debts**.
- **The receipt scanner only finds amounts with 2 decimals** (`receipt_scanner_screen.dart:31`). Many Pakistani receipts print "Rs 1,250" with no decimals, so they won't be detected.
- **PDF export will probably show empty boxes for Urdu names and text.** The `pdf` package's default font (Helvetica) has no Urdu/Arabic glyphs, and no custom font is loaded (`export_service.dart`). I didn't run it, but this is the known behavior.
- After **removing a member**, the members list doesn't refresh: `groupMembersProvider` is not invalidated (`group_detail_screen.dart:1161-1170`).

### Steps for the main actions
| Action | Taps (approx.) |
|---|---|
| Add equal-split expense | Open group → FAB → type title → type amount → (category) → Save = **4–5 taps + typing**. Good |
| Settle up | Balances tab → tap debt "Settle" → Confirm = **3 taps**. Good, but full amount only |
| Invite someone | Group → ⋮ → Share invite code → Share = **4 taps** |
| Join group | Groups → Join → type or scan code → Join = **3–4 taps** |

### Loading, empty, error, offline
- **Loading:** shimmer lists on the main tabs (`ShimmerList`), and spinners on buttons. Good.
- **Empty states:** they exist for groups, balances ("all settled") and expenses. Good.
- **Errors:** inconsistent. Some show `somethingWentWrong: $e` with the raw exception (`balances_tab.dart:41-44`), some show nothing (`group_detail_screen.dart:265`), and some show an empty list.
- **Offline:** **no handling at all.** There is no connectivity check, no cache, no retry, and no offline queue. Every action just fails with an error snackbar. The app also can't open without the network, because on startup it needs Firebase, Supabase and FCM setup before `runApp` (`main.dart:27-36`).

### Design, navigation and back button
- The colors and style (teal + gold, rounded cards, bottom sheets) are **consistent and look professional**. The `IndexedStack` keeps tabs alive (`home_screen.dart:39-42`).
- The back button works normally. But the hourly token refresh resets the whole stack (above), and sign-in/out always rebuilds the stack.

### Accessibility
- **Screen readers:** **0** `Semantics` widgets and **0** `semanticLabel`s. There are only **2** tooltips in all of `lib/`. Icon-only buttons (scan receipt, mic, attach, more menu) will be read as "button" with no name.
- **Small text:** **38** places use font size 8–11.
- **Contrast:** `primaryLight` `#14B8A6` is used as **text color** for labels on white or `#CCFBF1` (for example `settle_up_sheet.dart:145, 196`). That is about **2.5:1** contrast, well below the WCAG 4.5:1 minimum.
- **Tap targets:** many `GestureDetector`s wrap small icons or text, for example the settle chip at `group_detail_screen.dart:210`. I didn't measure them, but several look smaller than 48dp.
- **Text scaling:** I didn't test large system font sizes. With many fixed-height containers, overflow is likely.
- **RTL:** Urdu sets the locale, and Flutter flips the layout. I didn't check every screen in RTL.

### Usability score: **6 / 10**
Good: the flows are short, the look is nice, there are two languages, and it has many features. Bad: the hourly "kick to home" bug, raw error messages, no offline handling, rounded and mixed-currency totals, two switches that do nothing (recurring and group type), no expense edit or date, and almost no accessibility support.

---

## 4. Correctness and bugs

### 4.1 Money logic

**How it works:** each expense has one payer and N split rows (`amount_owed`, `is_settled`). Balances = the sum of all **unsettled** splits, netted **per pair of people** (`balances_controller.dart:128-186`). There is **no debt simplification** across the group. That is a deliberate choice (comment at `balances_controller.dart:103-107`) and it is fine. **Settling does not use the `settlements` table for math at all.** It only flips `is_settled = true` on split rows (`balances_controller.dart:219-237`).

#### ❌ Bug 1: Settling a netted debt gives wrong balances (serious)
The screen shows the **net** amount between two people, but settle-up only clears **one direction** of splits.

*Example:*
- Bilal pays 200 for dinner, split equally with Ali. **Ali owes Bilal 100.**
- Ali pays 120 for petrol, split equally. **Bilal owes Ali 60.**
- The app correctly shows: **"Ali owes Bilal 40."**
- Ali pays Bilal 40 and taps **Settle**.
- Code: marks Ali's splits on expenses *paid by Bilal* as settled (`.eq('paid_by', paidTo)` + `.eq('user_id', paidBy)`, lines 221-236). Bilal's 60 split on Ali's expense is **not** touched.
- **New balance: "Bilal owes Ali 60."** The real balance is **0**. The app is wrong by 60, and Bilal will be asked to pay money he doesn't owe.

This happens whenever two people have paid for each other, which is very common for flatmates.

#### ❌ Bug 2: Settle-up can clear debts the user never saw
The update clears **all** unsettled splits of that direction at the moment of the query, not the amount on screen. If Bilal adds a new 500 expense while Ali has the settle sheet open, Ali's new 250 share is also marked settled. The `settlements` row still says 40.

#### ❌ Bug 3: Totals add different currencies together
`balances_tab.dart:74-87` and `groups_tab.dart:127-136` add `youAreOwed` / `youOwe` across **all** groups, then label the result with **the first group's currency**.
*Example:* you are owed PKR 5,000 in "Flat" and you owe USD 20 in "Dubai Trip". The screen shows **"You owe PKR 20"**, and the home-screen widget shows the same.

#### ⚠️ Bug 4: Equal-split rounding loses paisa
`share = (amount / n).toStringAsFixed(2)` (`expenses_controller.dart:179-180`). There is no remainder handling.
*Example:* 100 split 3 ways gives 33.33 × 3 = 99.99. 0.01 disappears every time, so `totalSpent` and the split sums drift apart. It's small, but it is "always slightly wrong". The fix is to work in integer paisa and give the leftover paisa to someone.

#### ⚠️ Bug 5: Percentage split rejects 33.33 / 33.33 / 33.33
The check is `(total - 100).abs() > 0.01` (`add_expense_sheet.dart:160-167`). 33.33 × 3 = 99.99, and `100 - 99.99` in floating point is `0.010000000000005…`, which is greater than 0.01. So the save is **rejected**, and the user has to work out that they need 33.34. Percentage splits also round each share separately (`expenses_controller.dart:205-218`), so they can lose paisa too.

#### ⚠️ Bug 6: Monthly recurrence date overflow
`DateTime(now.year, now.month + 1, now.day)` (`expenses_controller.dart:106`). On 31 January this gives **3 March** (or 2 March in a leap year), not end of February. It doesn't matter today only because recurrence never runs (§1).

#### ⚠️ Other money issues
- **People who leave or are removed keep their debts.** Their splits stay in the balances, but they can't see the group anymore, so they can't settle from their side. Leaving is allowed with debts (`groups_controller.dart:229-244`).
- **Either side can mark a debt as paid, without the other person confirming.** A debtor can tap Settle and clear their own debt (UI allows both: `group_detail_screen.dart:208-211`). See §5.
- **No partial settlement and no undo.** If you settle by mistake, there's no way back except a fake expense.
- **Times are saved without a timezone.** `settled_at` and the typing `updated_at` use local time without UTC (`balances_controller.dart:233`, `chat_controller.dart:209`). If the columns are `timestamptz`, Postgres reads them as UTC, which is 5 hours off in Pakistan. That likely breaks the 5-second "is typing" check (`chat_controller.dart:301-302`). I'm not 100% sure, because the column types are not in the repo.
- **Three copies of the balance logic:** `balances_controller.dart`, an unused `groupBalancesProvider` (`expenses_controller.dart:227`), and TypeScript in `send-debt-reminders/index.ts:110-145`. They will drift apart over time.

**Answer to "are balances always correct?": No.** They are correct only when nobody has ever settled a pair of people who paid for each other, everyone uses one currency, and you don't care about lost paisa.

### 4.2 Half-saved data (several calls, no transaction)
Each of these runs 2+ separate HTTP calls. If the 2nd one fails (network drop, RLS error), the data is left broken:

| Flow | Calls | What breaks if call 2 fails |
|---|---|---|
| Create group | insert `groups` → insert `group_members` (`groups_controller.dart:149-165`) | **Orphan group** that has no members, so nobody can see it |
| Add expense | insert `expenses` → insert `expense_splits` (`expenses_controller.dart:111-127`) | **Expense with no splits**: counted in "total spent", but nobody owes anything |
| Delete expense | delete splits → delete expense (`expenses_controller.dart:140-147`) | Same as above |
| Settle up | insert `settlements` → update splits (`balances_controller.dart:210-237`) | A settlement is recorded and a "settled" push is sent, **but the debt is still there**. The user may pay twice |
| Send image / voice | upload file → insert message (`chat_controller.dart:231-247, 264-282`) | Orphan file in storage |
| Group / profile photo | upload → update row | Orphan file |
| Sign up | auth signUp → profile upsert (`auth_controller.dart:54-71`) | No profile row. There is a fallback at login, which is good |
| Join group | check membership → insert (`join_group_screen.dart:42-59`) | Double-tap race → a duplicate member, unless there is a unique constraint (unknown) |

**Extra problem with notifications:** the push webhook fires on `expenses` INSERT and then reads `expense_splits` to decide who to notify (`send-push-notification/index.ts:217-224`). The app inserts the splits **in a second request after that**, so the webhook often finds **zero splits and notifies nobody**. This is a race, so the result changes from one run to the next. The fix is one RPC that inserts both in one transaction.

Also, an expense whose included members list is empty can still be saved. `_submit` only checks `_members.isEmpty`, not whether anyone is still included (`add_expense_sheet.dart:139`). `_calculateSplits` then returns `[]` (`expenses_controller.dart:175`), and the expense row is already inserted.

### 4.3 Crashes, null errors, races
- **iOS crashes at launch:** `DefaultFirebaseOptions.currentPlatform` throws `UnsupportedError` on iOS (`firebase_options.dart:28-32`), and it is called before `runApp` (`main.dart:30`).
- **iOS crashes on camera, mic or photos:** `Info.plist` has no `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription` or `NSFaceIDUsageDescription`.
- **Hard casts that crash a whole list if one row is null:** `p['full_name'] as String` (`expenses_controller.dart:47`, `chat_controller.dart:71`), and `invite_code as String` / `created_by as String` in `GroupModel.fromMap`. One profile with a null name makes the **whole group's expense list** fail. In chat the error is caught, so the chat just looks empty.
- **Chat loads the OLDEST 100 messages, not the newest.** It uses `.order('created_at', ascending: true).limit(100)` (`chat_controller.dart:57-58`). After message 100, older history shows but **new messages from before you opened the chat never appear**. You only see messages that arrive live. There is no pagination.
- **Users can see the previous user's data after switching accounts.** No provider is `autoDispose` (0 uses in `lib/`), and nothing is invalidated on sign-out. `groupsProvider`, `myProfileProvider`, `notificationsProvider` and all `expensesProvider(id)` stay alive in the single `ProviderScope` (`main.dart:36`). If you log out and log in as another user, you can briefly see the previous user's groups, profile and notifications until a refresh. `currentUserProvider` is a plain `Provider` that caches the first user (`auth_controller.dart:13-15`).
- **`JoinGroupController.joinGroup`** returns `'Not signed in'` but leaves `state` stuck on loading (`join_group_screen.dart:24-25`).
- **The app lock triggers on `paused`** (`main.dart:112-116`). Opening the camera, gallery, share sheet or Google sign-in pauses the app, so the lock fires while you're using the app's own features.
- **`_tickRecordTimer` uses recursive `Future.delayed`** with no maximum recording length (`chat_screen.dart:371-377`). A user can record a very large file.

---

## 5. Security

### What I could check
- **Keys:** `.env` holds only `SUPABASE_URL` and `SUPABASE_ANON_KEY` (it is git-ignored, but bundled into the APK, which is OK for the anon key). The Firebase Android API key is in `firebase_options.dart:56`. That is normal for Firebase, but **restrict it** in Google Cloud (Android app + SHA-1). The Google web client ID is hardcoded (`auth_controller.dart:130`), which is fine because it isn't secret. I found **no service-role key in the app**. Good. The Edge Functions read secrets from env. Good.
- **Auth flow:** Supabase email/password plus Google `signInWithIdToken`. Password reset uses the deep link `com.splitly.app://callback`. supabase_flutter v2 uses PKCE by default, which protects against custom-scheme hijacking. The minimum password is **6 characters** (`signup_screen.dart:171`), which is weak for a money app.
- **Edge Functions** check a shared `x-webhook-secret` header (`send-push-notification/index.ts:118`, `send-debt-reminders/index.ts:83`). That is OK. They return `String(e)` in error responses, which is a minor information leak.

### App lock (PIN / biometric)
- The PIN is **4 digits**, stored as an **unsalted SHA-256** in **SharedPreferences** (`app_lock_controller.dart:18, 35-39`). There are only 10,000 possible PINs, so anyone who can read the prefs file (rooted phone, `adb backup`) can reverse it in under a second. Use `flutter_secure_storage` (Keystore/Keychain) plus a salted slow hash, or rely on device credentials.
- **No limit on wrong attempts** (`unlock_screen.dart:45-60`). Someone can try every PIN by hand.
- **The lock doesn't cover screens opened on top of Home.** `_AppLockWrapper` wraps only the `HomeScreen` route (`main.dart:121, 167, 223`). Group detail, chat and others are opened with `Navigator.push` **above** it. If the phone locks while you're in a chat and you return, **the chat is still visible**, and the unlock screen is hidden underneath. The fix is to put the lock in `MaterialApp.builder` so it overlays everything.
- **Notifications show message text and amounts** on the lock screen and in the shade, even with app lock on (`fcm_service.dart:139-156`).

### Things a malicious user might abuse
I can't confirm these without the SQL. Each one depends on how RLS is written. Please check each one:
1. **Join any group without the code.** Joining is a plain client `insert` into `group_members` (`join_group_screen.dart:55-59`). If the INSERT policy only checks `user_id = auth.uid()`, anyone who knows a `group_id` can join. Group IDs leak, for example in **public** chat-attachment URLs (`{groupId}/{file}`, `chat_controller.dart:231-237`) and in notification payloads.
2. **Make yourself admin.** `setMemberRole` is a plain `update` on `group_members` (`groups_controller.dart:247-261`). If members can update their own row, they can set `role = 'admin'`.
3. **Clear your own debt.** Settling is a plain `update` of `expense_splits.is_settled` (`balances_controller.dart:231-236`), and the UI lets the debtor do it without the creditor agreeing. Even with "correct" RLS, this is a **product** problem: a creditor should confirm "I got paid".
4. **Make fake debts for other people.** `addExpense` sends any `paid_by` and any split `user_id`s (`expenses_controller.dart:111-127`). Unless RLS checks that they are all members of that group, a user can create debts between other people, or put non-members into splits. Negative amounts are blocked only in the UI (`add_expense_sheet.dart:135`). Check for a `CHECK (amount > 0)` constraint.
5. **Archive or rename any group you're in.** There's no role check in the UI (`groups_controller.dart:177-191`). It depends on the `groups` UPDATE policy.
6. **Public storage.** All three buckets use `getPublicUrl`. Anyone with a link can view **private chat photos, voice notes and avatars** forever, without logging in. Use private buckets and signed URLs for `chat-attachments` at least.
7. **Push notifications go to the wrong person after logout.** `fcm_token` is never cleared on sign-out (`auth_controller.dart:215-221`). It is only saved at **app start**, and only if a session already exists (`main.dart:35`, `fcm_service.dart:162-186`). So:
   - after logout, the phone **keeps getting the old user's messages and amounts**;
   - after a fresh login, the new user gets **no push** until they restart the app.
8. **The FCM token is printed to the log** (`fcm_service.dart:167`), along with 60 other `print`s, some with user data (`groups_controller.dart:87, 103`, which print full group rows). `print` output shows up in `adb logcat` on release builds too.
9. **Spam.** There is no rate limiting on messages, typing upserts or expenses. Every message triggers a push to the whole group.

---

## 6. Performance

- **Startup does a fan-out of N+1 requests.** The Groups tab and Balances tab (both kept alive by `IndexedStack`) watch the balance for **every group**, which loads `expensesProvider(group.id)` for every group (`balances_tab.dart:52-54`, `groups_tab.dart:129-136`). Each one makes **2 requests** and downloads **all expenses and all splits ever** (no date limit, no pagination). Groups themselves take 3 requests. With **100 groups that's about 200 requests** at launch, and possibly MBs of JSON. A server-side `get_my_balances()` RPC or a view would make this **1 request**.
- **Provider leak: `groupBalanceSummaryProvider` uses a `Map` as its family key** (`balances_controller.dart:35-54`). Called as `groupBalanceSummaryProvider({'groupId': …})` in 5 places. A Dart `Map` literal is only equal to itself, so **every build creates a new provider**, and since nothing is `autoDispose`, **none are ever freed**. Memory grows with every rebuild, and the result is never cached. The fix is to use `groupId` (or a record) as the key.
- **Chat makes 2 DB writes per keystroke.** `_onTextChanged` calls `setTyping(true)` on **every character** (`chat_screen.dart:68-78`), and each call does a `profiles` select plus a `typing_status` upsert (`chat_controller.dart:196-210`). Typing a 50-character message = **100 requests**. It also calls `setState` on every key. The fix is to send "typing" once and then refresh it every ~3 s.
- **Realtime channels are never closed.** `messagesProvider` is not `autoDispose`, so `ref.onDispose` (`chat_controller.dart:28`) **never runs** while the app is open. Every chat you open keeps a live websocket subscription for the rest of the session. Each incoming realtime message also does an extra `profiles` query (`chat_controller.dart:131-136`).
- **After every write, the whole list is re-fetched** (`expenses_controller.dart:129, 148`, `groups_controller.dart:168, 182, 190, 276`).
- **The push Edge Function** gets a **new Google OAuth token for every recipient** (`send-push-notification/index.ts:86`) and sends **one by one**. A 20-member group = 20 token exchanges + 20 sends per chat message. Cache the token for about 55 minutes and use `Promise.all`.
- **The debt-reminder function** loops over **every non-archived group in the whole database**, with several queries per group and per pair (`send-debt-reminders/index.ts:89-195`). At 1,000 users it's slow. At 10k+ it will hit the Edge Function timeout. It should be one SQL query.
- **Unread counts, notifications and balances don't refresh live.** That's not a speed problem, but it means people will pull-to-refresh a lot, which adds load.
- **Indexes:** I can't check them. You need indexes on `group_members(user_id)`, `group_members(group_id)`, `expenses(group_id, created_at)`, `expense_splits(expense_id)`, `expense_splits(user_id, is_settled)`, `messages(group_id, created_at)` and `notifications(user_id, created_at)`.

**At 1,000 users or 100 groups per user:** cold start becomes very slow (hundreds of requests), memory grows from the provider leak and the full expense lists, chat history breaks after 100 messages, push sending gets slow and costly, and the reminder cron times out. 1,000 users × a few groups each is fine for Supabase itself. **The client design is the bottleneck, not the database.**

---

## 7. Code quality and maintainability

**Good:**
- The feature folders are clear and the names are understandable.
- Localization is done properly with ARB files: about 1,000 strings in English and Urdu.
- There are helpful comments explaining *why* (for example `main.dart:170-175`, `balances_controller.dart:103-107`).
- The theme is centralized (`app_theme.dart`).
- The Edge Function respects per-type mute preferences.

**Problems:**
- **61 `print()` calls** left in `lib/` (26 in `groups_controller.dart` alone), some logging user data and the FCM token. There is no logger.
- **Leftover "✅ FIX" / "✅ new" comments** everywhere, and duplicated section comments (`chat_controller.dart:159-160, 219-220`). These read like notes from a debugging session, not finished code.
- **Duplicated code:** member loading appears twice in `add_expense_sheet.dart` (lines 84-114 and 230-250), the balance algorithm exists 3 times, and the FCM sending code is copied into both Edge Functions.
- **Very large widget files:** `chat_screen.dart` (1,447 lines), `group_detail_screen.dart` (1,231), `reports_screen.dart` (982) and `add_expense_sheet.dart` (976). They mix UI, logic and DB calls.
- **No data/repository layer.** Supabase table names and column strings are spread across about 20 files. `Map<String, dynamic>` is passed around instead of models (for example `groupMembersProvider` returns raw maps, and members in the add-expense form are maps).
- **Money is stored in `double`.** Use integer minor units (paisa) or `Decimal`.
- **Errors are handled differently in different places:** some functions rethrow, some return `'Error: $e'` strings, and some return `[]`.
- **`analysis_options.yaml`** uses default lints only. `avoid_print` is ignored in some places with `// ignore:`.
- Dead files and unused packages (§1, §2).

**Tests:** there is **one test file**, the **default Flutter counter test**, and it **fails**: it pumps an empty `MaterialApp` and expects a "0" (`test/widget_test.dart`). There are **zero real tests**. The most important missing tests are unit tests for `_calculateSplits`, `_calculateGroupBalance`, `_pairwiseDebts` and settle-up. Those are exactly where the bugs in §4 are.

**Could another developer take over?** For the **Flutter side, yes, with some effort.** It's readable and the structure is predictable. Plan about 1–2 days to get oriented. For the **backend, not really.** The schema, RLS policies, 4 RPCs, database webhooks, the pg_cron job and the storage bucket settings **exist only inside your live Supabase project**. A new developer, or a client, **cannot rebuild the backend from this repo**. That's the biggest handover risk.

---

## 8. Production readiness

| Item | Status |
|---|---|
| **Release signing** | ❌ Release is **signed with the debug key** (`build.gradle.kts:45-50`). Google Play will reject this |
| **targetSdk** | ❌ `targetSdk = 34` (`build.gradle.kts:31`). Play needs API 35+ for app updates since Aug 2025, and newer rules for new apps keep rising. Check the current requirement and set the latest |
| Package name | ✅ Android `com.splitly.app`. ❌ iOS is still `com.example.splitly` (`project.pbxproj:375, 554, 576`) |
| Version | `1.0.0+1`. OK for a first release |
| **iOS** | ❌ Not set up: no Firebase iOS options (it crashes at launch), no `GoogleService-Info.plist`, no permission strings, no URL scheme for the auth deep link, no APNs / push setup, and Google Sign-In on iOS needs a reversed client ID URL scheme. **App Store rule 4.8: if you offer Google login you must also offer Sign in with Apple** (or a similar privacy-focused login) |
| Account deletion | 🟡 In-app deletion exists (`profile_tab.dart:207-435` → RPC `delete_own_account`, not in repo). Google Play also needs a **web link** where users can ask for deletion without the app |
| Privacy policy | 🟡 The file exists (`privacy-policy.html`), but it must be **hosted at a public URL**. **The contact email has a typo:** `innovativefaahd44@gmail.com` (`privacy-policy.html:225`). It also says receipt images may be stored, which the code doesn't do. Make sure the Play "Data safety" form matches |
| Email | ❓ I can't see the Supabase auth email settings. Supabase's built-in SMTP is heavily rate-limited (a few emails per hour). For real users you need a custom SMTP (Resend, SendGrid, SES) and branded templates |
| Crash reporting | ❌ None (no Crashlytics, no Sentry) |
| Analytics | None. That's fine, but you'll be blind after launch |
| Logging | ❌ 61 `print`s, including the FCM token |
| Backend in source control | ❌ No migrations, RLS, RPCs or cron |
| Tests / CI | ❌ None / none |
| App size | ⚠️ 5 ML Kit script models are bundled (`build.gradle.kts:39-43`), and Latin is enough |
| Offline / error UX | ❌ (see §3) |
| Notification tap handling | ❌ TODO |
| App name | ❓ "Splitly" may already be used by other apps or companies. Check Play Store / App Store and trademarks before launch |

### Production-readiness score: **3 / 10**
Android works as a demo. It can't be uploaded to Play as-is (debug signing), iOS doesn't start, the money math has real bugs, and the backend can't be reproduced.

---

## 9. Honest verdict

**What it is:** a **feature-rich MVP, and a strong portfolio piece.** The *range* of features is impressive for a solo project: chat with voice notes, OCR, push with mute settings, Urdu, PDF export, reports, app lock and a widget. It looks good and the main flows are short. But it's **not production-ready**. The weak points are exactly the ones a finance app can't have: **wrong balances after settling, no transactions, unverifiable security, and no iOS.**

**Can you sell or white-label it as it is?**
- **As a demo / portfolio piece to show clients what you can build: yes, today.** Just demo it on Android and avoid settle-up between two people who both paid.
- **As a product handed to a client: no, not yet.** A client will need (a) correct money math, (b) the backend in the repo so they can deploy their own copy (that's what white-labeling means), (c) iOS, and (d) store-ready builds. White-labeling also needs the brand name, colors, currency list and Firebase/Supabase config to be **configurable**. Right now they are hardcoded in many places (`'PKR'` defaults, app name, `com.splitly.app` redirect URLs, the Google client ID).

### Top 10 fixes, ranked by impact

| # | Fix | Why | Difficulty | Time |
|---|---|---|---|---|
| 1 | **Rewrite settle-up and balance math.** Treat settlements as ledger entries: balance = splits − settlements. Settle via one RPC. Support partial payments and undo. Store money as integer paisa and give the leftover paisa to someone | Balances are wrong today (§4.1 Bugs 1, 2, 4, 5) | Medium–Hard | 3–4 days |
| 2 | **Move multi-step writes into Postgres RPC functions** (create group, add/delete expense + splits, settle, join by code) so each is one transaction | Stops half-saved data and fixes the expense-notification race (§4.2) | Medium | 2–3 days |
| 3 | **Put the backend in the repo** (`supabase/migrations`: schema, RLS, RPCs, triggers, webhooks, cron, buckets) and **audit RLS** for the 6 abuse cases in §5 | Security + handover + white-label | Medium | 2–3 days |
| 4 | **Fix the auth/session bugs:** don't navigate on `tokenRefreshed`, reset all providers on sign-out (or use `autoDispose`), save the FCM token on every sign-in and clear it on sign-out | Hourly kick-to-home, data and pushes leaking between accounts | Easy | 0.5–1 day |
| 5 | **Store-ready Android:** real upload keystore, latest targetSdk, remove the extra ML Kit models and unused packages, remove `print`s, add Crashlytics or Sentry | Can't publish without it | Easy | 1 day |
| 6 | **Fix the app lock:** overlay via `MaterialApp.builder`, secure storage, salted hash, attempt limit / back-off, hide notification content when locked, don't lock on own camera/picker | The lock is easy to get around today | Medium | 1 day |
| 7 | **Performance:** one `get_my_balances` RPC instead of loading every expense, fix the `Map` family key leak, `autoDispose` chat providers, load the newest messages + pagination, debounce typing, cache the OAuth token in the Edge Function | Slow start, memory growth, chat history bug | Medium | 2 days |
| 8 | **Multi-currency and display fixes:** group totals by currency, show 2 decimals, fix the receipt amount decimals, add a Unicode font (e.g. Noto Naskh Urdu) to the PDF | Wrong totals, Urdu PDF broken | Easy–Medium | 1 day |
| 9 | **iOS setup:** Firebase iOS, bundle ID, permission strings, URL schemes, APNs, Sign in with Apple, test on a device | Half of the market. Needs a Mac | Medium | 3–4 days |
| 10 | **Finish or remove half features + UX polish:** recurring (build a cron or hide the switch), group category, expense edit + date picker, notification tap navigation, settlement history, friendly error messages, admin-only archive, block leaving with debts, plus **unit tests for the money logic** | Users trust what they see. Tests stop #1 from coming back | Medium | 4–5 days |

**Rough total to reach a solid v1.0 on both stores: about 4–5 weeks of focused work for one developer.** Fixes #1–#5 (about 1.5–2 weeks) are the minimum before any real user or client uses it with real money.
