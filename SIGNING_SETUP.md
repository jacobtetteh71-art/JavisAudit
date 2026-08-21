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
