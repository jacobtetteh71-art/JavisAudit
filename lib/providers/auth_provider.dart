// ============================================================
// providers/auth_provider.dart  –  Login/Logout State Manager
// ============================================================
// Handles everything about protecting the app's data:
//   • First-time PIN + backup password setup
//   • Checking a PIN or password typed on the Lock Screen
//   • Locking out repeated wrong guesses (see the Lockout section)
//   • The current session's logged-in/out state
//   • Logging out (locks the app again without deleting any data)
//
// IMPORTANT: "isLoggedIn" only lives in memory (for this app
// session). Every time the app is fully closed and reopened, the
// user has to unlock again — that's the whole point of a lock
// screen protecting the business's financial data.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:local_auth/local_auth.dart';
import '../database/database_helper.dart';
import '../utils/auth_helper.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;      // Session state — resets on app restart
  bool _hasCredentials = false;  // Whether a PIN has ever been set up
  bool _isLoading = true;

  bool get isLoggedIn     => _isLoggedIn;
  bool get hasCredentials => _hasCredentials;
  bool get isLoading      => _isLoading;

  // ── Failed-attempt lockout ───────────────────────────────────
  // Deliberately per-device, NOT synced to the cloud — it lives in
  // the local Hive 'settings' box (already opened in main.dart),
  // same place notification flags live. That's the right home for
  // it: it's a property of "how many wrong guesses THIS phone has
  // seen recently", not part of the business's ledger data.
  //
  // Shared between PIN and password attempts on purpose — both
  // unlock the same data, so counting them separately would let
  // someone reset the counter just by switching fields.
  Box get _lockBox => Hive.box('settings');

  static const int _maxAttemptsBeforeLockout = 5;
  // Every _escalateEvery additional failures beyond the first
  // lockout moves one step further down this schedule (capped at
  // the last entry), so someone hammering "Unlock" over and over
  // keeps getting slower, not just once.
  static const int _escalateEvery = 3;
  static const List<Duration> _lockoutSchedule = [
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
  ];

  int get _failedAttempts => _lockBox.get('pin_failed_attempts', defaultValue: 0) as int;

  DateTime? get _lockedUntil {
    final iso = _lockBox.get('pin_locked_until') as String?;
    return iso == null ? null : DateTime.tryParse(iso);
  }

  /// True while a lockout from too many wrong PIN/password attempts
  /// is still active. The Lock Screen checks this before even trying
  /// to verify, and disables its input while it's true.
  bool get isLockedOut {
    final until = _lockedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// How much longer the current lockout has to run, or null if
  /// there isn't an active one. The Lock Screen uses this to show a
  /// "try again in Xs" countdown.
  Duration? get lockoutRemaining {
    final until = _lockedUntil;
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  Future<void> _onFailedAttempt() async {
    final attempts = _failedAttempts + 1;
    await _lockBox.put('pin_failed_attempts', attempts);
    if (attempts >= _maxAttemptsBeforeLockout) {
      final overBy = attempts - _maxAttemptsBeforeLockout;
      final bucket = (overBy ~/ _escalateEvery).clamp(0, _lockoutSchedule.length - 1);
      final lockDuration = _lockoutSchedule[bucket];
      await _lockBox.put('pin_locked_until', DateTime.now().add(lockDuration).toIso8601String());
    }
  }

  Future<void> _onSuccessfulUnlock() async {
    await _lockBox.put('pin_failed_attempts', 0);
    await _lockBox.delete('pin_locked_until');
  }

  // ── Biometric unlock (fingerprint / Face) ────────────────────
  // An ALTERNATIVE to typing the PIN, not a replacement for it —
  // the PIN is still what's actually stored and verified underneath;
  // biometrics just skip having to type it in, gated by whatever
  // fingerprint/face the phone's own OS already trusts. Whether this
  // is turned on is a simple per-device preference, stored in the
  // same local Hive 'settings' box the failed-attempt lockout uses
  // above — deliberately NOT synced to the cloud, since "does this
  // particular phone offer fingerprint unlock" has no meaning on a
  // different device.
  final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _biometricEnabledKey = 'biometric_unlock_enabled';

  bool get isBiometricEnabled => _lockBox.get(_biometricEnabledKey, defaultValue: false) as bool;

  // Whether THIS device actually offers usable biometrics right now
  // (has the hardware AND at least one fingerprint/face already
  // enrolled in the phone's own Settings app) — checked before ever
  // showing a biometric toggle or button, since offering one that
  // can't work is just a confusing dead end.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  // Turns biometric unlock on. Requires a real successful biometric
  // check first — so turning the toggle on IS itself proof it
  // actually works on this device/for this person, rather than
  // trusting the hardware-availability check alone.
  Future<bool> enableBiometric() async {
    final verified = await authenticateWithBiometrics(
      reason: 'Confirm your fingerprint/face to enable biometric unlock',
    );
    if (!verified) return false;
    await _lockBox.put(_biometricEnabledKey, true);
    notifyListeners();
    return true;
  }

  Future<void> disableBiometric() async {
    await _lockBox.put(_biometricEnabledKey, false);
    notifyListeners();
  }

  // Shows the OS's own fingerprint/Face dialog and returns whether it
  // succeeded. On success, this behaves exactly like a correct PIN —
  // it logs the session in and clears any failed-PIN-attempt lockout
  // state, since the owner has just proven their identity by a
  // different, equally valid means. A failed/cancelled biometric
  // attempt does NOT count against the PIN's own lockout counter —
  // the OS's biometric prompt already has its own independent
  // attempt limit, so stacking this app's PIN lockout on top of it
  // as well would be punishing the same person twice for one failure.
  Future<bool> authenticateWithBiometrics({String? reason}) async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason ?? 'Unlock JavisAudit',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (didAuthenticate) {
        _isLoggedIn = true;
        await _onSuccessfulUnlock();
        notifyListeners();
      }
      return didAuthenticate;
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }

  // ── loadAuthStatus: called once on app startup ─────────────
  // Checks whether a PIN has already been set up, so SplashScreen
  // knows whether to show the Lock Screen or the PIN Setup screen.
  Future<void> loadAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    final row = await DatabaseHelper.instance.getAuthCredentials();
    _hasCredentials = row != null && row['pin_hash'] != null;

    _isLoading = false;
    notifyListeners();
  }

  // ── setupCredentials: first-time PIN + backup password setup ─
  // Called from SetPinScreen, right after Onboarding (or later,
  // from Settings, when the user wants to change their PIN).
  Future<bool> setupCredentials(String pin, String password) async {
    try {
      final salt = AuthHelper.generateSalt();
      final pinHash = await AuthHelper.hashAsync(pin, salt);
      final passwordHash = await AuthHelper.hashAsync(password, salt);

      await DatabaseHelper.instance.saveAuthCredentials(
        pinHash: pinHash,
        passwordHash: passwordHash,
        salt: salt,
      );

      // A fresh PIN means any previous lockout no longer applies.
      await _onSuccessfulUnlock();

      _hasCredentials = true;
      // Setting up credentials also counts as being logged in,
      // so the user lands straight on the Dashboard afterwards.
      _isLoggedIn = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting up login credentials: $e');
      return false;
    }
  }

  // ── verifyPin: called when the user types their PIN to unlock ─
  Future<bool> verifyPin(String pin) async {
    if (isLockedOut) return false;

    final row = await DatabaseHelper.instance.getAuthCredentials();
    if (row == null || row['pin_hash'] == null || row['auth_salt'] == null) {
      return false;
    }
    final storedHash = row['pin_hash'] as String;
    final salt = row['auth_salt'] as String;
    final isValid = await AuthHelper.verify(pin, salt, storedHash);

    if (isValid) {
      _isLoggedIn = true;
      await _onSuccessfulUnlock();
      // Opportunistic upgrade: if this PIN was still stored using
      // the old single-round SHA-256 format, re-save it under the
      // new PBKDF2 format now that we've confirmed the owner typed
      // it correctly. Silent — nothing for the business owner to do.
      if (AuthHelper.isLegacyFormat(storedHash)) {
        final upgradedHash = await AuthHelper.hashAsync(pin, salt);
        await DatabaseHelper.instance.updatePinHash(upgradedHash);
      }
    } else {
      await _onFailedAttempt();
    }
    notifyListeners();
    return isValid;
  }

  // ── verifyPassword: the "Forgot PIN? Use password instead" path ─
  Future<bool> verifyPassword(String password) async {
    if (isLockedOut) return false;

    final row = await DatabaseHelper.instance.getAuthCredentials();
    if (row == null || row['password_hash'] == null || row['auth_salt'] == null) {
      return false;
    }
    final storedHash = row['password_hash'] as String;
    final salt = row['auth_salt'] as String;
    final isValid = await AuthHelper.verify(password, salt, storedHash);

    if (isValid) {
      _isLoggedIn = true;
      await _onSuccessfulUnlock();
      if (AuthHelper.isLegacyFormat(storedHash)) {
        final upgradedHash = await AuthHelper.hashAsync(password, salt);
        await DatabaseHelper.instance.updatePasswordHash(upgradedHash);
      }
    } else {
      await _onFailedAttempt();
    }
    notifyListeners();
    return isValid;
  }

  // ── logout: locks the app again ────────────────────────────
  // Does NOT delete any data — purely a session flag flip.
  // The next screen shown should be the LockScreen.
  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }

  // ── confirmPin / confirmPassword: "verify it's really you" ──
  // Used for re-authentication checks INSIDE the app — e.g. before
  // changing the PIN, editing the business profile, deleting a
  // record, or restoring a backup. Unlike verifyPin/verifyPassword
  // (used on the Lock Screen), these do NOT change _isLoggedIn —
  // the user is already logged in; we're just double-checking their
  // identity for one sensitive action. Deliberately NOT subject to
  // the Lock Screen's failed-attempt lockout: the device is already
  // unlocked at this point, so the higher-value target (getting
  // past the Lock Screen itself) is what the lockout protects.
  Future<bool> confirmPin(String pin) async {
    final row = await DatabaseHelper.instance.getAuthCredentials();
    if (row == null || row['pin_hash'] == null || row['auth_salt'] == null) return false;
    return AuthHelper.verify(pin, row['auth_salt'] as String, row['pin_hash'] as String);
  }

  Future<bool> confirmPassword(String password) async {
    final row = await DatabaseHelper.instance.getAuthCredentials();
    if (row == null || row['password_hash'] == null || row['auth_salt'] == null) return false;
    return AuthHelper.verify(password, row['auth_salt'] as String, row['password_hash'] as String);
  }
}
