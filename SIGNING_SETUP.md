# Release Signing Setup

## Why this exists

Every Android app is signed with a cryptographic key, and Android
refuses to install an "update" that's signed with a **different**
key than whatever's already on the phone — it just fails with
"App not installed as package conflicts with an existing package."

Until now, this project's release build was signed with the
throwaway **debug** key instead of a real one — fine for a first
build, but GitHub Actions gives you a brand-new machine every single
run, so (without the cache this project's workflow now has) a
freshly random debug key would get generated on every build. Every
APK conflicted with the last one, forcing an uninstall before every
single install.

The workflow's cache fix (`.github/workflows/build-apk.yml`) already
makes the debug key stable across builds, so installs should now
work without you doing anything else. But a **real** release
keystore — one you generate once, keep safe, and reuse forever — is
still the right way to do this long-term (it's also required before
you could ever publish to the Play Store, which won't accept an app
signed with a debug key at all). This doc is for setting that up
whenever you're ready; nothing here is required to fix the immediate
"conflicts with an existing package" problem — that's already fixed.

## 1. Generate a keystore (do this once, on your own computer)

You need a JDK installed (any recent one). Run:

```bash
keytool -genkey -v -keystore javisaudit-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias javisaudit
```

It'll ask for a keystore password, your name/organization details
(these aren't security-sensitive, just identify you as the signer),
and a key password (you can reuse the keystore password if you want
one less thing to track).

**Keep `javisaudit-release-key.jks` somewhere safe and back it up.**
If you lose it, you can never publish an update to an app that used
it — you'd have to ship a brand-new app listing from scratch. Never
commit it to GitHub (it's already excluded via `.gitignore`).

## 2. Add it to GitHub Actions as secrets

In your GitHub repo: **Settings → Secrets and variables → Actions →
New repository secret**. Add these four:

| Secret name | Value |
|---|---|
| `KEYSTORE_BASE64` | Output of `base64 -i javisaudit-release-key.jks` (base64-encode the whole file, then paste that text) |
| `KEYSTORE_PASSWORD` | The keystore password you chose |
| `KEY_ALIAS` | `javisaudit` (or whatever alias you used above) |
| `KEY_PASSWORD` | The key password you chose |

On macOS/Linux, `base64 -i javisaudit-release-key.jks` prints the
encoded text directly. On Windows (PowerShell):
`[Convert]::ToBase64String([IO.File]::ReadAllBytes("javisaudit-release-key.jks"))`

## 3. That's it

The next push automatically picks these up — the workflow decodes
the keystore and writes `android/key.properties`, which
`android/app/build.gradle` reads and switches to for signing. No
other change needed. If the secrets aren't set, everything falls
back to the (now-stable) cached debug key exactly as before, so
there's no rush to do this — just know it's the real long-term fix.

## 4. Enabling "Continue with Google" (Cloud Sync)

The app's code side of Google Sign-In is already done — this is the
one-time Firebase console step that only you can do, since it needs
your project login.

1. **Get your app's SHA-1 fingerprint.** This has to be the SAME
   keystore your APK is actually signed with:
   - If you've set up a real release keystore (steps 1–3 above):
     `keytool -list -v -keystore javisaudit-release-key.jks -alias javisaudit`
   - If you're still on the cached debug key (no release keystore
     yet), you'll need the debug keystore's fingerprint instead —
     the simplest way is to add a temporary step to
     `.github/workflows/build-apk.yml` right after the "Restore
     stable debug keystore" step: `run: keytool -list -v -keystore
     ~/.android/debug.keystore -storepass android -alias
     androiddebugkey`, read the SHA-1 out of that run's log, then
     remove the temporary step again.
   - Either way, copy the `SHA1:` line from the output (looks like
     `AA:BB:CC:...`).

2. **Add it to Firebase.** Firebase console → Project Settings →
   your Android app (`com.javisaudit.app`) → "Add fingerprint" →
   paste the SHA-1 → Save.

3. **Enable Google as a sign-in method.** Firebase console →
   Authentication → Sign-in method → Google → Enable → Save.

4. **Download `google-services.json`** from that same Project
   Settings page and add it at `android/app/google-services.json` —
   this project doesn't have one yet (it currently runs on
   `firebase_options.dart` alone), but `android/app/build.gradle` and
   `android/settings.gradle` already check for this exact file and
   turn on the Google Services Gradle plugin automatically the moment
   it exists — nothing else to wire up. Commit and push it (it's not
   a secret — it's fine in the repo, same as `firebase_options.dart`).

That's it — no code changes needed beyond that file. "Continue with
Google" is available both on the Sign In screen (for restoring an
account onto a new device) and inside Settings → Cloud Sync (for
creating or signing into an account in the first place).
