// ============================================================
// utils/auth_helper.dart  –  Login Security Helper
// ============================================================
// We NEVER store the user's actual PIN or password anywhere.
// Instead we store a "salted, iterated hash" — a one-way scrambled
// version that can be checked against, but never reversed back into
// the original PIN/password.
//
// "Salt" = a random string mixed in before hashing, so that even if
// two users pick the same PIN (e.g. "1234"), their stored hashes
// look completely different.
//
// "Iterated" = the hash function is run tens of thousands of times
// in a row (PBKDF2-HMAC-SHA256) instead of just once. This is the
// part that actually matters for a short secret like a 4-6 digit
// PIN: a single SHA-256 pass can be brute-forced in well under a
// second on ordinary hardware (a 4-digit PIN is only 10,000
// possibilities to try). Repeating the hash 20,000 times makes each
// guess 20,000x more expensive — the difference between "crackable
// instantly" and "crackable, but slow enough not to be worth it" if
// a stored hash is ever exposed.
//
// That threat model matters more than it otherwise would here
// because, since Cloud Sync was added, this hash (never the PIN
// itself) can leave the device — it travels inside the `settings`
// row synced to Firestore (see database_helper.dart and
// services/sync_service.dart), which is what lets "sign in on a new
// phone" restore your old PIN too. Firestore's security rules (see
// SYNC_SETUP.md) already lock that document to the account owner
// only — but "assume a stored hash could someday be read" is the
// right posture for anything that leaves the device at all.
//
// BACKWARDS COMPATIBILITY: any PIN/password set up before this file
// was upgraded was hashed with a single, fast SHA-256 round.
// verify() still recognises and accepts that old format, so nobody
// already using the app gets locked out. AuthProvider transparently
// re-hashes with the new, iterated scheme the moment that old
// PIN/password is typed correctly again — see isLegacyFormat() below
// — so existing installs upgrade themselves over time with no
// action needed from the business owner.
// ============================================================

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show compute;

// Marks a hash as the new format, e.g. "pbkdf2$20000$3f9a...".
// Anything NOT starting with this is a legacy single-round SHA-256
// hex digest (see _legacyHash).
const String _pbkdf2Prefix = 'pbkdf2';

// Tiny plain-data bundle so hashing work can be shipped over to a
// background isolate via compute() below — isolates can only
// exchange simple, self-contained objects like this one, never
// closures or live objects.
class _Pbkdf2Job {
  final String rawText;
  final String salt;
  final int iterations;
  const _Pbkdf2Job(this.rawText, this.salt, this.iterations);
}

// The actual isolate entry point. Must be a top-level (or static)
// function for compute() to accept it — this is why it lives outside
// the AuthHelper class, even though it calls back into AuthHelper's
// private static helpers (legal in Dart: privacy is per-file, not
// per-class, so a top-level function in this same file can still
// reach AuthHelper._pbkdf2Bytes / ._bytesToHex).
String _pbkdf2Worker(_Pbkdf2Job job) {
  final digest = AuthHelper._pbkdf2Bytes(job.rawText, job.salt, job.iterations);
  return AuthHelper._bytesToHex(digest);
}

class AuthHelper {
  // How many HMAC-SHA256 rounds a NEW PIN/password hash uses. This
  // is a balance point for a phone-class device: high enough to make
  // offline brute-forcing meaningfully expensive, low enough that
  // unlocking the app (done on a background isolate — see
  // hashAsync/verify) still feels instant. There's no single "right"
  // number here; if you profile this on real target hardware and it
  // ever feels slow, lower it — if it feels instant, you have room
  // to raise it. The iteration count travels inside the stored hash
  // itself (see hashAsync), so changing this constant later never
  // breaks verification of hashes created under the old count.
  static const int _iterations = 20000;
  static const int _keyLengthBytes = 32; // SHA-256 digest length

  // Generates a random 16-byte salt (called once, the very first
  // time the user sets up their PIN/password), base64url-encoded to
  // a printable string for easy storage.
  static String generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  // ── New hashing path — use this for every NEW hash ───────────
  // Runs PBKDF2-HMAC-SHA256 on a background isolate (via compute())
  // so 20,000 rounds of hashing never freezes the UI thread while
  // someone is waiting to unlock the app, and returns a
  // self-describing string: "pbkdf2$<iterations>$<hex digest>".
  static Future<String> hashAsync(String rawText, String salt) async {
    final hex = await compute(_pbkdf2Worker, _Pbkdf2Job(rawText, salt, _iterations));
    return '$_pbkdf2Prefix\$$_iterations\$$hex';
  }

  // ── Legacy path — verification ONLY, never used to create new hashes ──
  // The single-round SHA-256 scheme every hash used before this file
  // was upgraded to PBKDF2. Kept only so pre-upgrade PINs/passwords
  // keep working until they're opportunistically re-hashed.
  static String _legacyHash(String rawText, String salt) {
    final bytes = utf8.encode('$salt:$rawText');
    return sha256.convert(bytes).toString();
  }

  // Whether a stored hash still uses the old, single-round format.
  // AuthProvider checks this after a successful verify() to decide
  // whether to transparently upgrade that hash.
  static bool isLegacyFormat(String storedHash) => !storedHash.startsWith('$_pbkdf2Prefix\$');

  // ── verify: checks a freshly-typed PIN/password against whatever
  // format the stored hash happens to be in ───────────────────────
  static Future<bool> verify(String rawText, String salt, String storedHash) async {
    if (!isLegacyFormat(storedHash)) {
      final parts = storedHash.split('\$');
      if (parts.length != 3) return false; // malformed — fail closed
      final iterations = int.tryParse(parts[1]);
      if (iterations == null) return false;
      final expectedHex = parts[2];
      final computedHex = await compute(_pbkdf2Worker, _Pbkdf2Job(rawText, salt, iterations));
      return _constantTimeEquals(computedHex, expectedHex);
    }
    // Legacy format: a bare hex SHA-256 digest, no prefix.
    return _constantTimeEquals(_legacyHash(rawText, salt), storedHash);
  }

  // ── PBKDF2-HMAC-SHA256, implemented directly against the `crypto`
  // package so no extra dependency is needed ──────────────────────
  // Standard PBKDF2 construction (RFC 8018 §5.2, single-block-aware):
  // derive `_keyLengthBytes` of key material by repeatedly re-hashing
  // an HMAC chain `iterations` times per block and XOR-folding every
  // round together.
  static List<int> _pbkdf2Bytes(String rawText, String salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(rawText));
    final saltBytes = utf8.encode(salt);
    const blockSize = 32; // sha256 digest length
    final blocksNeeded = (_keyLengthBytes / blockSize).ceil();
    final output = <int>[];

    for (int blockIndex = 1; blockIndex <= blocksNeeded; blockIndex++) {
      // U1 = HMAC(password, salt || INT_32_BE(blockIndex))
      var u = hmac.convert([
        ...saltBytes,
        (blockIndex >> 24) & 0xff,
        (blockIndex >> 16) & 0xff,
        (blockIndex >> 8) & 0xff,
        blockIndex & 0xff,
      ]).bytes;
      var t = List<int>.from(u);

      for (int round = 1; round < iterations; round++) {
        u = hmac.convert(u).bytes;
        for (int i = 0; i < t.length; i++) {
          t[i] ^= u[i];
        }
      }
      output.addAll(t);
    }
    return output.sublist(0, _keyLengthBytes);
  }

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  // Constant-time string comparison — prevents an attacker who
  // somehow gets to time repeated verify() calls from learning how
  // many leading characters of a guess were already correct.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
