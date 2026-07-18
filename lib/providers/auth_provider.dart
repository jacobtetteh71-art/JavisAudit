// ============================================================
// providers/auth_provider.dart  –  Login/Logout State Manager
// ============================================================
// Handles everything about protecting the app's data:
//   • First-time PIN + backup password setup
//   • Checking a PIN or password typed on the Lock Screen
//   • The current session's logged-in/out state
//   • Logging out (locks the app again without deleting any data)
//
// IMPORTANT: "isLoggedIn" only lives in memory (for this app
// session). Every time the app is fully closed and reopened, the
// user has to unlock again — that's the whole point of a lock
// screen protecting the business's financial data.
// ============================================================

import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../utils/auth_helper.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;      // Session state — resets on app restart
  bool _hasCredentials = false;  // Whether a PIN has ever been set up
  bool _isLoading = true;

  bool get isLoggedIn     => _isLoggedIn;
  bool get hasCredentials => _hasCredentials;
  bool get isLoading      => _isLoading;

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
      final pinHash = AuthHelper.hash(pin, salt);
      final passwordHash = AuthHelper.hash(password, salt);

      await DatabaseHelper.instance.saveAuthCredentials(
        pinHash: pinHash,
        passwordHash: passwordHash,
        salt: salt,
      );

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
    final row = await DatabaseHelper.instance.getAuthCredentials();
    if (row == null || row['pin_hash'] == null || row['auth_salt'] == null) {
      return false;
    }
    final isValid = AuthHelper.verify(pin, row['auth_salt'] as String, row['pin_hash'] as String);
    if (isValid) {
      _isLoggedIn = true;
      notifyListeners();
    }
    return isValid;
  }

  // ── verifyPassword: the "Forgot PIN? Use password instead" path ─
  Future<bool> verifyPassword(String password) async {
    final row = await DatabaseHelper.instance.getAuthCredentials();
    if (row == null || row['password_hash'] == null || row['auth_salt'] == null) {
      return false;
    }
    final isValid =
        AuthHelper.verify(password, row['auth_salt'] as String, row['password_hash'] as String);
    if (isValid) {
      _isLoggedIn = true;
      notifyListeners();
    }
    return isValid;
  }

  // ── logout: locks the app again ────────────────────────────
  // Does NOT delete any data — purely a session flag flip.
  // The next screen shown should be the LockScreen.
  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }
}
