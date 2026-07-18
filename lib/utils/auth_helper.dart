// ============================================================
// utils/auth_helper.dart  –  Login Security Helper
// ============================================================
// We NEVER store the user's actual PIN or password anywhere.
// Instead we store a "salted hash" — a one-way scrambled version
// that can be checked against, but never reversed back into the
// original PIN/password. This is the same basic principle real
// banking apps use.
//
// "Salt" = a random string mixed in before hashing, so that even
// if two users pick the same PIN (e.g. "1234"), their stored
// hashes look completely different.
// ============================================================

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class AuthHelper {
  // Generates a random 16-character salt (called once, the very
  // first time the user sets up their PIN/password)
  static String generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  // Combines the salt + raw text, then runs it through SHA-256.
  // Same input (same salt + same PIN) always produces the same
  // hash — which is how we can later check a login attempt
  // without ever storing the original PIN/password.
  static String hash(String rawText, String salt) {
    final bytes = utf8.encode('$salt:$rawText');
    return sha256.convert(bytes).toString();
  }

  // Compares a freshly-typed PIN/password against the stored hash
  static bool verify(String rawText, String salt, String storedHash) {
    return hash(rawText, salt) == storedHash;
  }
}
