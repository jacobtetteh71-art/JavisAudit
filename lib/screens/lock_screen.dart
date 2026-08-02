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
//
// The entry field uses the same soft, rounded, icon-prefixed
// treatment as the Sign In panel on the Welcome screen, so the
// whole app's "type a credential in" moments feel like one
// consistent, modern design language.
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

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  final _pinCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _usePasswordInstead = false;
  bool _isChecking = false;
  String? _errorText;

  // A short horizontal shake on the entry card when the PIN/password
  // is wrong — a small, deliberate bit of motion that says "try
  // again" without needing an extra word of copy.
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _passwordCtrl.dispose();
    _shakeController.dispose();
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
      _shakeController.forward(from: 0);
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Profile picture / logo ────────────────────
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: hasPicture
                    ? ClipOval(
                        child: Image.file(
                          File(profile!.profileImagePath!),
                          width: 88, height: 88, fit: BoxFit.cover,
                        ),
                      )
                    : ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Image.asset('assets/app_icon_mark.png', fit: BoxFit.contain),
                        ),
                      ),
              ),
              const SizedBox(height: 18),

              Text(
                'Welcome back${profile != null ? "," : ""}',
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

              const Spacer(flex: 2),

              // ── Floating white entry card ─────────────────
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) => Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_outline, size: 15, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            _usePasswordInstead ? 'Enter your backup password' : 'Enter your PIN to continue',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Soft, rounded, icon-prefixed field — the same
                      // treatment used on the Welcome screen's Sign In panel
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: _errorText != null ? Border.all(color: AppColors.expense, width: 1.2) : null,
                        ),
                        child: _usePasswordInstead
                            ? TextField(
                                controller: _passwordCtrl,
                                obscureText: true,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  prefixIcon: Icon(Icons.password, size: 20, color: AppColors.textMuted),
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
                                style: const TextStyle(fontSize: 22, letterSpacing: 10, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  counterText: '',
                                  hintText: '••••',
                                  hintStyle: TextStyle(letterSpacing: 10),
                                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                                ),
                                onSubmitted: (_) => _unlock(),
                              ),
                      ),

                      if (_errorText != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 14, color: AppColors.expense),
                            const SizedBox(width: 6),
                            Text(_errorText!, style: const TextStyle(color: AppColors.expense, fontSize: 12.5)),
                          ],
                        ),
                      ],

                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          ),
                          onPressed: _isChecking ? null : _unlock,
                          child: _isChecking
                              ? const SizedBox(
                                  height: 20, width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Unlock', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 6),
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
                          style: const TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
