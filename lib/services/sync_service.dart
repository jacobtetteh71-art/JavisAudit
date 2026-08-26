// ============================================================
// services/sync_service.dart  –  Online (Cloud) Sync
// ============================================================
// This is the ONLY file in the app that talks to Firebase. It
// answers two questions every time "Sync Now" is tapped:
//
//   1. Where should this device's data go? (Sign in / sign up
//      with an email + password, via Firebase Auth)
//   2. Which copy of the data is newer — this phone's, or the
//      one already sitting in the cloud? (Firestore)
//
// DESIGN — read this before changing anything below:
// ------------------------------------------------------------
// JavisAudit is offline-first: every screen reads/writes SQLite
// directly and works with zero internet connection. Cloud Sync
// is bolted on TOP of that, not woven through it. That trade-off
// is deliberate for a single-owner ledger app (one business
// owner, occasionally switching between an old phone and a new
// one) — it keeps the sync code in one file instead of touching
// every insert/update across 20+ screens.
//
// It works as a whole-dataset snapshot sync:
//   • PUSH  = upload everything from DatabaseHelper.exportAllData()
//             as one Firestore document.
//   • PULL  = download that document and feed it straight into
//             DatabaseHelper.restoreFromBackup() (the same method
//             the local "Restore from Backup" feature already used).
//   • Two timestamps decide the direction automatically:
//       - sync_meta.last_modified_at (this device)  — stamped by
//         SQLite triggers, see database_helper.dart
//       - the cloud document's own last_modified_at
//     If only one side changed since the last successful sync,
//     that side wins automatically. If BOTH changed, we don't
//     guess — the caller (SyncProvider/UI) is told to ask the
//     owner to choose "Keep This Device" or "Keep Cloud Copy".
//
// LIMITATION worth knowing (and worth mentioning in your defense
// if asked): this is last-write-wins at the whole-dataset level,
// not a field-by-field merge. That's the right trade-off for a
// single owner using one phone at a time, but it is NOT true
// multi-device *simultaneous* editing. Documenting that trade-off
// clearly is normal, expected practice — not a weakness to hide.
// ============================================================

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../database/database_helper.dart';

// The three things a "Sync Now" tap can end in.
enum SyncOutcome {
  upToDate,  // nothing to do, both sides already match
  pushed,    // local data was newer → uploaded to the cloud
  pulled,    // cloud data was newer → downloaded onto this device
  conflict,  // BOTH sides changed since the last sync — needs a choice
}

// Thrown by syncNow() when a conflict is found. The UI catches
// this, asks the owner which copy to keep, then calls
// resolveConflict(keepLocal: ...) with their answer.
class SyncConflictException implements Exception {
  final DateTime localModifiedAt;
  final DateTime cloudModifiedAt;
  SyncConflictException(this.localModifiedAt, this.cloudModifiedAt);
}

class SyncService {
  SyncService._privateConstructor();
  static final SyncService instance = SyncService._privateConstructor();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Auth state ──────────────────────────────────────────────
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Each business owner's data lives at:
  //   sync_backups/{uid}   (one document — the whole snapshot)
  DocumentReference<Map<String, dynamic>> _cloudDoc(String uid) {
    return _firestore.collection('sync_backups').doc(uid);
  }

  // ── Sign up: brand-new sync account ─────────────────────────
  Future<void> signUp({required String email, required String password}) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  // ── Sign in: existing sync account (e.g. new/replacement phone) ─
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Sign in / register with Google ──────────────────────────
  // Same underlying call whether this is someone's very first time
  // (creates the Firebase account transparently) or a returning
  // sign-in on a new device — Firebase's signInWithCredential()
  // doesn't distinguish the two. Returns null if the person closed
  // the Google account picker without choosing one (not an error —
  // just "they changed their mind"), so callers can tell that apart
  // from a real failure. On success, check
  // result.additionalUserInfo?.isNewUser to know which of those two
  // cases this was, since the app needs to react differently: a
  // brand-new account still needs the Onboarding wizard for business
  // details, while a returning one goes straight into the normal
  // "pull data down from the cloud" restore flow.
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // picker dismissed, not an error

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  // Signs out of the CLOUD SYNC account only. The local PIN lock
  // (AuthProvider) is completely separate — signing out here never
  // touches or deletes any data on the device.
  Future<void> signOut() async {
    await _auth.signOut();
    // Also disconnect any cached Google session — otherwise a later
    // "Continue with Google" could silently re-pick the same account
    // without ever showing the picker, which would be a confusing
    // way to "sign back in" right after choosing to sign out. Guarded
    // because this throws if Google was never used to sign in at all.
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  // ── syncNow: the main entry point ────────────────────────────
  // Returns how the sync resolved. Throws SyncConflictException
  // if the owner needs to make a choice (call resolveConflict next).
  Future<SyncOutcome> syncNow() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in to Cloud Sync.');
    }

    final meta = await DatabaseHelper.instance.getSyncMeta();
    if (meta == null) {
      throw StateError('This database has not been migrated for sync yet.');
    }

    final localModifiedAt = DateTime.parse(meta['last_modified_at'] as String);
    final lastSyncedAt = meta['last_synced_at'] != null
        ? DateTime.parse(meta['last_synced_at'] as String)
        : null;

    final cloudSnap = await _cloudDoc(user.uid).get();

    // Nothing in the cloud yet at all → this is the very first
    // sync for this account. Push straight away, no comparison needed.
    if (!cloudSnap.exists) {
      await _push(user.uid, localModifiedAt);
      return SyncOutcome.pushed;
    }

    final cloudData = cloudSnap.data()!;
    final cloudModifiedAt = (cloudData['last_modified_at'] as Timestamp).toDate();

    final localChangedSinceSync =
        lastSyncedAt == null || localModifiedAt.isAfter(lastSyncedAt);
    final cloudChangedSinceSync =
        lastSyncedAt == null || cloudModifiedAt.isAfter(lastSyncedAt);

    if (localChangedSinceSync && cloudChangedSinceSync) {
      // Both sides moved on since we last agreed — don't guess.
      throw SyncConflictException(localModifiedAt, cloudModifiedAt);
    } else if (localChangedSinceSync) {
      await _push(user.uid, localModifiedAt);
      return SyncOutcome.pushed;
    } else if (cloudChangedSinceSync) {
      await _pull(user.uid, cloudData, cloudModifiedAt);
      return SyncOutcome.pulled;
    } else {
      return SyncOutcome.upToDate;
    }
  }

  // ── resolveConflict: called after the owner picks a side ────
  Future<void> resolveConflict({required bool keepLocal}) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in to Cloud Sync.');

    if (keepLocal) {
      final meta = await DatabaseHelper.instance.getSyncMeta();
      final localModifiedAt = DateTime.parse(meta!['last_modified_at'] as String);
      await _push(user.uid, localModifiedAt, force: true);
    } else {
      final cloudSnap = await _cloudDoc(user.uid).get();
      final cloudData = cloudSnap.data()!;
      final cloudModifiedAt = (cloudData['last_modified_at'] as Timestamp).toDate();
      await _pull(user.uid, cloudData, cloudModifiedAt);
    }
  }

  // ── _push: upload this device's data, overwriting the cloud ─
  Future<void> _push(String uid, DateTime localModifiedAt, {bool force = false}) async {
    final data = await DatabaseHelper.instance.exportAllData();
    // Firestore documents store JSON-like maps directly, but
    // nesting everything as one pre-built JSON string keeps this
    // 100% identical in shape to the local backup file (easier to
    // reason about, and trivially reusable if we ever want a
    // "download your cloud backup as a file too" button).
    final jsonString = jsonEncode(data);

    final now = DateTime.now();
    await _cloudDoc(uid).set({
      'payload_json': jsonString,
      'last_modified_at': Timestamp.fromDate(localModifiedAt),
      'synced_at': Timestamp.fromDate(now),
    });

    await DatabaseHelper.instance.markSynced(syncedAt: now, cloudUid: uid);
  }

  // ── _pull: download the cloud snapshot onto this device ──────
  Future<void> _pull(
    String uid,
    Map<String, dynamic> cloudData,
    DateTime cloudModifiedAt,
  ) async {
    final jsonString = cloudData['payload_json'] as String;
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    await DatabaseHelper.instance.restoreFromBackup(data);

    final now = DateTime.now();
    // Adopt the cloud's modified time as our own — this device is
    // now exactly caught up with what the cloud had.
    await DatabaseHelper.instance.setSyncTimestamps(
      modifiedAt: cloudModifiedAt,
      syncedAt: now,
    );
    await DatabaseHelper.instance.markSynced(syncedAt: now, cloudUid: uid);
  }
}
