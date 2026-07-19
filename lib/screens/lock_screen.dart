// ============================================================
// screens/lock_screen.dart  –  App Unlock Screen
// ============================================================
// Shown every time the app is opened (after Splash), if a PIN has
// already been set up. This is what actually protects the user's
// business data — no PIN/password, no access to the Dashboard.
//
// Two ways to unlock:
//   1. Enter the PIN (the everyday path)
//   2. Tap "Forgot PIN? Use password instead" and enter the
//      backup password set up during onboarding
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../utils/utils.dart';
import 'main_nav_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _usePasswordInstead = false;
  bool _isChecking = false;
  String? _errorText;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _isChecking = true;
      _errorText = null;
    });

    final auth = context.read<AuthProvider>();
    final bool isValid = _usePasswordInstead
        ? await auth.verifyPassword(_passwordCtrl.text.trim())
        : await auth.verifyPin(_pinCtrl.text.trim());

    if (!mounted) return;

    if (isValid) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _isChecking = false;
        _errorText = _usePasswordInstead ? 'Incorrect password. Try again.' : 'Incorrect PIN. Try again.';
      });
      _pinCtrl.clear();
      _passwordCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read the business profile so we can personalize the greeting
    // and show the owner's chosen profile picture (if any)
    final profile = context.watch<ProfileProvider>().profile;
    final hasPicture =
        profile?.profileImagePath != null && File(profile!.profileImagePath!).existsSync();

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Profile picture / logo, replacing the plain lock icon ──
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: hasPicture
                    ? ClipOval(
                        child: Image.file(
                          File(profile!.profileImagePath!),
                          width: 96, height: 96, fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.storefront, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 20),

              // ── Personalized logged-out message ───────────────
              Text(
                'Logged out${profile != null ? "," : ""}',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15),
              ),
              if (profile != null) ...[
                const SizedBox(height: 2),
                Text(
                  profile.businessName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    _usePasswordInstead ? 'Enter your backup password' : 'Enter your PIN to continue',
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── PIN or password field, depending on mode ────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _usePasswordInstead
                    ? TextField(
                        controller: _passwordCtrl,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Password',
                          contentPadding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        onSubmitted: (_) => _unlock(),
                      )
                    : TextField(
                        controller: _pinCtrl,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontSize: 24, letterSpacing: 8),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          hintText: '••••',
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _unlock(),
                      ),
              ),

              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(_errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isChecking ? null : _unlock,
                  child: _isChecking
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Unlock'),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  setState(() {
                    _usePasswordInstead = !_usePasswordInstead;
                    _errorText = null;
                    _pinCtrl.clear();
                    _passwordCtrl.clear();
                  });
                },
                child: Text(
                  _usePasswordInstead ? 'Use PIN instead' : 'Forgot PIN? Use password instead',
                  style: TextStyle(color: Colors.white.withOpacity(0.85)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
