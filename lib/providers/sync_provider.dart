// ============================================================
// providers/sync_provider.dart  –  Cloud Sync UI State
// ============================================================
// Thin ChangeNotifier wrapper around SyncService, following the
// same pattern as every other provider in this app: the SCREEN
// never talks to Firebase directly, it only talks to this class.
// ============================================================

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../services/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  bool _isSyncing = false;
  String? _errorMessage;
  DateTime? _lastSyncedAt;

  // Set only while a conflict from the last syncNow() call is
  // waiting on the owner's decision. Non-null → the UI should
  // show the "Keep This Device / Keep Cloud Copy" dialog.
  SyncConflictException? _pendingConflict;

  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  SyncConflictException? get pendingConflict => _pendingConflict;

  bool get isSignedIn => SyncService.instance.isSignedIn;
  User? get currentUser => SyncService.instance.currentUser;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  SyncProvider() {
    _loadLastSyncedAt();
    // Keep isSignedIn/currentUser fresh across sign-in/out/token refresh
    SyncService.instance.authStateChanges.listen((_) => notifyListeners());

    // Auto-sync the moment the phone comes back online — this is
    // what makes Cloud Sync feel automatic rather than a chore the
    // owner has to remember to do. It's silent (no dialogs) unless
    // it turns up a genuine conflict, in which case the UI (if the
    // Sync screen happens to be open) will prompt as usual.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && isSignedIn && !_isSyncing) {
        syncNow();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadLastSyncedAt() async {
    final meta = await DatabaseHelper.instance.getSyncMeta();
    final raw = meta?['last_synced_at'] as String?;
    _lastSyncedAt = raw != null ? DateTime.parse(raw) : null;
    notifyListeners();
  }

  // ── Auth actions ──────────────────────────────────────────
  Future<bool> signUp(String email, String password) => _runAuthAction(
        () => SyncService.instance.signUp(email: email, password: password),
      );

  Future<bool> signIn(String email, String password) => _runAuthAction(
        () => SyncService.instance.signIn(email: email, password: password),
      );

  Future<void> signOut() async {
    await SyncService.instance.signOut();
    notifyListeners();
  }

  Future<bool> sendPasswordReset(String email) => _runAuthAction(
        () => SyncService.instance.sendPasswordReset(email),
      );

  Future<bool> _runAuthAction(Future<void> Function() action) async {
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyAuthError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // Translates Firebase's error codes into plain language a
  // non-technical business owner can actually act on.
  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That email already has a sync account. Try signing in instead.';
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      case 'weak-password':
        return 'Please choose a password with at least 6 characters.';
      case 'user-not-found':
      case 'invalid-credential':
        return 'No sync account found with that email and password.';
      case 'wrong-password':
        return 'That password is incorrect.';
      case 'network-request-failed':
        return 'No internet connection. Check your data/Wi-Fi and try again.';
      default:
        return e.message ?? 'Sync account error. Please try again.';
    }
  }

  // ── Sync action ───────────────────────────────────────────
  Future<void> syncNow() async {
    _isSyncing = true;
    _errorMessage = null;
    _pendingConflict = null;
    notifyListeners();

    try {
      await SyncService.instance.syncNow();
      await _loadLastSyncedAt();
    } on SyncConflictException catch (e) {
      _pendingConflict = e;
    } on StateError catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Sync failed. Check your internet connection and try again.';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Called by the conflict dialog once the owner picks a side.
  Future<void> resolveConflict({required bool keepLocal}) async {
    _isSyncing = true;
    notifyListeners();
    try {
      await SyncService.instance.resolveConflict(keepLocal: keepLocal);
      _pendingConflict = null;
      await _loadLastSyncedAt();
    } catch (e) {
      _errorMessage = 'Could not finish syncing. Please try again.';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void dismissConflict() {
    _pendingConflict = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
