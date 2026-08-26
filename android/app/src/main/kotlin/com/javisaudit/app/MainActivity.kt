// ============================================================
// MainActivity.kt  –  Native Android Entry Point
// ============================================================
// FlutterFragmentActivity (not the plain FlutterActivity most
// Flutter templates start with) — required by local_auth for
// fingerprint/Face unlock: Android's BiometricPrompt API needs a
// FragmentActivity host to attach its dialog to. See
// styles.xml's LaunchTheme/NormalTheme comment for the other half
// of this same requirement.
// ============================================================
package com.javisaudit.app

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
