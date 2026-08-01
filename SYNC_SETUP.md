# Cloud Sync — Setup Guide

JavisAudit now has an **online sync** feature (see More → Cloud Sync in the
app). It's built and ready in the code, but — same as the rest of the app —
it needs a real Firebase project behind it before it will actually work.
Everything below is a one-time setup, done on **your own computer with
internet access** (this sandbox has no route to Firebase's servers, so it
could not be done here).

## 1. Create a free Firebase project

1. Go to https://console.firebase.google.com
2. "Add project" → name it e.g. `javisaudit` → you can skip Google
   Analytics (not needed).

## 2. Install the two CLIs (one-time, on your machine)

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

## 3. Generate your real firebase_options.dart

From inside the `javisaudit/` project folder:

```bash
firebase login
flutterfire configure
```

- Pick the Firebase project you just created.
- When asked which platforms, choose **Android** only (this project only
  ships Android).
- This **overwrites** `lib/firebase_options.dart` with your real values and
  also downloads a real `android/app/google-services.json`, replacing the
  placeholder ones committed here.

## 4. Turn on the two Firebase products the app uses

In the Firebase console, for your project:

- **Authentication** → Sign-in method → enable **Email/Password**.
- **Firestore Database** → Create database → any region close to Ghana
  (e.g. `europe-west1`) → start in **production mode**.

## 5. Paste in the Firestore security rules

Production mode locks everything down by default. In Firestore →
**Rules**, replace the default with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /sync_backups/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

This is the whole security model: a signed-in owner can only ever read or
write their **own** single backup document (`sync_backups/{their-uid}`),
never anyone else's.

## 6. Build and test

```bash
flutter pub get
flutter run
```

Try it with two things logged as different owners on two devices/emulators
(or the same device twice, signing out between) to see push/pull and the
conflict dialog in action.

## What changed in the codebase

- `pubspec.yaml` — added `firebase_core`, `firebase_auth`,
  `cloud_firestore`, `connectivity_plus`.
- `lib/database/database_helper.dart` — DB version 8 → 9. Added a
  `sync_meta` table plus SQLite triggers on every data table, so the app
  always knows "has anything changed since the last sync?" without
  touching the 100+ existing insert/update call sites. Also widened the
  existing `exportAllData()` / `restoreFromBackup()` (used by both the
  local JSON backup AND Cloud Sync) to cover every table, not just the
  original five.
- `lib/services/sync_service.dart` — new. All Firebase Auth + Firestore
  calls live here.
- `lib/providers/sync_provider.dart` — new. UI-facing state (signed in?,
  syncing?, last synced, errors) + auto-sync when connectivity returns.
- `lib/screens/sync_screen.dart` — new. Sign in/create account, "Sync
  Now", and the "Keep This Device / Keep Cloud Copy" conflict dialog.
- `lib/screens/more_screen.dart` — added a "Cloud Sync" menu entry.
- `lib/main.dart` — initialises Firebase (safely no-ops if not yet
  configured) and registers `SyncProvider`.
- `android/settings.gradle`, `android/app/build.gradle` — added the
  `google-services` Gradle plugin.
- `android/app/src/main/AndroidManifest.xml` — added the `INTERNET` and
  `ACCESS_NETWORK_STATE` permissions.

## ⚠️ Important for your report/defense

Chapter/section documentation that previously stated JavisAudit was
**"architecturally incapable of making network calls"** (the old comment
at the top of `AndroidManifest.xml`, and reportedly Section 8.1 of your
system design doc) is now **no longer accurate** and should be revised.
The app is still **offline-first** — every screen keeps working with zero
internet, and no data leaves the device unless the owner deliberately
signs in to Cloud Sync — but it is not offline-*only* anymore. Worth
updating that section before your defense so an examiner doesn't catch
the contradiction between your docs and the shipped APK.

## Known limitation, worth stating plainly rather than hiding

Cloud Sync uses **whole-dataset, last-write-wins** synchronization (see
the design note at the top of `sync_service.dart`), not a field-by-field
merge. That's the right trade-off for a single owner moving between
phones, but it is *not* true simultaneous multi-device editing — if you
want to discuss this as a "Future Work" item in your report, that's an
easy, honest paragraph to write.
