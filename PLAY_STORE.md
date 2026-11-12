# Splitly on Google Play — checklist

Everything you need to do in the **Play Console** (play.google.com/console) to publish Splitly for Android. Do it in this order. Items marked **⚠️** can block the release.

---

## 1. The signing key — decide this first ⚠️

**What it is:** Android only installs an update if it is signed with the **same key** as the version already on the phone.

**Today:** every Splitly APK (v1.2.0, v1.3.0) is signed with this laptop's **debug key** (`C:\Users\DELL\.android\debug.keystore`). Google Play **does not accept** debug-signed apps.

**How Play works (Play App Signing):**
- You make your own **upload key** and sign the `.aab` with it before uploading.
- Google checks your upload key, then **re-signs** the app with Google's own **app signing key** before it reaches phones.
- So phones that install from Play get an app signed by **Google's key**, not your debug key.

**What this means for your friends:**
- They have the sideloaded app (debug key). The Play version has a different key, so it **can't update** their app.
- **Once**, each friend uninstalls the old app and installs Splitly from Play.
- Their **data is safe**: groups, expenses and balances are on the server. Only phone-only settings are lost (app lock PIN, language choice), and they log in again.
- After that, all updates come from Play. Stop sending APKs.

**Steps:**
1. Make the upload key (once). In a terminal, from the project folder:
   ```
   keytool -genkey -v -keystore splitly-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Put the `.jks` file **outside** the project folder, and never commit it.
2. Copy `android/key.properties.example` to `android/key.properties` and fill in the path, passwords and alias. That file is git-ignored.
3. **Keep the upload key and its passwords somewhere safe that you control** (for example a password manager). If you lose it, Google can reset it, but that takes days.
4. Build: `flutter build appbundle --release`. With `key.properties` present it's signed with your upload key (`android/app/build.gradle.kts`).
5. In Play Console → your app → **Setup → App signing**: keep **"Let Google manage and protect your app signing key"** (the default).
6. **⚠️ Google Sign-In:** copy the **SHA-1** of **both** keys from Play Console → App signing (the "app signing key" and the "upload key"). Add them to **Firebase → Project settings → Your Android app → SHA fingerprints**, and to the Android OAuth client in Google Cloud. Without this, "Continue with Google" fails in the Play version.
7. Keep `C:\Users\DELL\.android\debug.keystore` until all friends have moved to the Play version. Until then it's the only way to give them an update.

---

## 2. Create the app

- **App name:** Splitly (max 30 characters). ⚠️ Check that the name is free on Play and not a trademark.
- **Default language:** English (United States). Add **Urdu** under Store presence → Translations.
- **App or game:** App. **Free or paid:** Free.
- **Package name:** `com.splitly.app` (set by the first upload; it can never change).

---

## 3. App content (Policy → App content)

### Privacy policy
`https://fahad1084.github.io/splitly/privacy-policy.html`

### App access ⚠️
Splitly needs a login, so reviewers need one:
- Choose **"All or some functionality is restricted"**.
- Give a **test account** (email + password) on the **live** project, with a demo group and a few expenses. Don't use a real friend's account.

### Ads
**No**, the app has no ads.

### Content rating
Fill in the questionnaire (category **"All other app types"**):
- Violence, sexual content, drugs, gambling: **No**.
- **Users can interact or exchange content:** **Yes** (group chat with text, photos and voice).
- Shares the user's location: **No**. Digital purchases: **No**.

Expected result: low rating (Everyone / PEGI 3–12, depending on the user-interaction answer).

### Target audience
Choose **18 and over** (or 13+). The privacy policy says the app is not for children under 13. Don't choose any age under 13, or the stricter Families rules apply.

### Financial features
Splitly **only records** who owes whom. It doesn't move money, give loans, or handle payments or crypto. Answer **"My app doesn't provide any financial features"**.

### Government app / News / Health
**No** to each.

### Data safety ⚠️ (answers from what the app really sends)

**Does the app collect or share user data?** **Yes, collects.** It is **not shared**: Supabase and Google Firebase work for us (service providers), which Play doesn't count as "sharing", and group-mates only see data the user chose to put into a group.

**Is all data encrypted in transit?** **Yes** (HTTPS everywhere).

**Can users ask for their data to be deleted?** **Yes**: in the app (Profile → Delete Account), and on the web page in section 4 below.

| Play category → data type | Collected? | Required or optional | Why (purpose) |
|---|---|---|---|
| Personal info → **Name** | Yes | Required | App functionality, Account management |
| Personal info → **Email address** | Yes | Required | Account management |
| Personal info → **Phone number** | Yes | **Optional** (only if the user adds it) | App functionality |
| Personal info → **User IDs** (account id) | Yes | Required | App functionality, Account management |
| Financial info → **Other financial info** (expense amounts, who paid whom) | Yes | Required | App functionality |
| Messages → **Other in-app messages** (group chat) | Yes | Optional | App functionality |
| Photos and videos → **Photos** (profile photo, group photo, chat photos) | Yes | Optional | App functionality |
| Audio → **Voice or sound recordings** (voice messages) | Yes | Optional | App functionality |
| App activity → **Other user-generated content** (expense titles and notes) | Yes | Required | App functionality |
| App info and performance → **Crash logs** (Firebase Crashlytics, release builds only) | Yes | Required (automatic) | Analytics (finding and fixing crashes) |
| Device or other IDs → **Device or other IDs** (push notification token) | Yes | Required for notifications | App functionality |

**NOT collected** (answer "No"):
- **Location, contacts, calendar, files, web history, health, payment card or bank details.**
- **Receipt photos:** read on the phone only (on-device text recognition), never uploaded.
- **Microphone and camera:** only used when the user records or takes a photo; the result is listed above.

For every type: **not processed ephemerally**, **not shared**.

---

## 4. Account deletion web page ⚠️

Play needs a **web link** where people can ask for deletion **without the app**. Easiest: one more page on GitHub Pages (`legal-docs` branch, next to the privacy policy), for example `https://fahad1084.github.io/splitly/delete-account.html`. It should say:
1. **In the app:** Profile → Delete Account. This is possible once nobody owes you money and you owe nobody.
2. **Without the app:** email `innovativefahad44@gmail.com` from the address you signed up with, subject "Delete my Splitly account". We delete it within 30 days.
3. **What is deleted and what stays:** the same list as the privacy policy, section 4.

Then enter that URL in **Data safety → Data deletion**.

---

## 5. Store listing (Grow → Store presence → Main store listing)

| Item | Rule |
|---|---|
| Short description | Max 80 characters, for example: *"Split bills with friends, track who owes whom, and settle up — in English and Urdu."* |
| Full description | Max 4,000 characters: features, offline, Urdu, privacy |
| App icon | 512 × 512 PNG |
| Feature graphic | 1024 × 500 PNG/JPG |
| Phone screenshots | At least 2 (better 4–8), from the real app, without real people's names or amounts |
| Category | **Finance** |
| Contact email | `innovativefahad44@gmail.com` (required, shown publicly) |
| Website | Optional |

Add the same texts in **Urdu** under Translations.

---

## 6. Testing and release

- ⚠️ **New personal developer accounts** must first run a **closed test with at least 12 testers for 14 days in a row** before they can apply for production. Your friends are ideal testers: add their Google emails to a closed testing track.
- Upload the `.aab` (not an APK) in **Test and release → Testing → Closed testing**, then later **Production**.
- Each upload needs a **higher version code** (`version: x.y.z+N` in `pubspec.yaml`, where N goes up by 1).
- Target API: already **36** (Play's requirement).

---

## 7. After launch

- **Firebase Crashlytics** shows crashes from Play installs.
- **Supabase:** before many users join, switch Auth emails to your **own SMTP** (Supabase's built-in email sender only allows a few emails per hour). Dashboard → Authentication → SMTP Settings.
- Keep the **upload key** safe (section 1).

---

## What the code already handles (no action needed)
- Target SDK 36, a real release build with R8.
- `.aab` build: `flutter build appbundle --release` (the file is in `build/app/outputs/bundle/release/app-release.aab`).
- In-app account deletion that really removes personal data.
- Privacy policy hosted, with Crashlytics and deletion explained.
- Permissions are explained in the privacy policy. Camera and microphone are asked for only when the user scans, takes a photo or records. Notifications are asked for once when the app starts.
