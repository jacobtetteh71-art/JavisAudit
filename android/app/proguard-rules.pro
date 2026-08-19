# ============================================================
# android/app/proguard-rules.pro
# ============================================================
# REQUIRED for sqflite_sqlcipher (see its README's "Android"
# section): this project's release build has minifyEnabled=true
# (see android/app/build.gradle), and without these keep rules,
# R8/ProGuard's code shrinking silently strips or renames
# SQLCipher's native-bridge classes. That doesn't fail the BUILD —
# it fails at RUNTIME, the very first time the release APK tries to
# open the (now encrypted) database, with an error that gives no
# hint it's a ProGuard problem. Debug builds are unaffected (no
# shrinking), which is exactly why this is easy to miss: it only
# breaks the release build CI actually ships.
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-dontwarn net.sqlcipher.**
