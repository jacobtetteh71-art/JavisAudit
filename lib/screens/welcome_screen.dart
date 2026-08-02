// ============================================================
// screens/welcome_screen.dart  –  First-Launch Welcome Screen
// ============================================================
// Shown once, the very first time the app is opened (before any
// business profile exists). Gives the owner a clear choice —
// Register a new business, or Sign In if they already have an
// account set up on this device — instead of dropping them
// straight into the setup wizard with no context.
// ============================================================

import 'package:flutter/material.dart';

import '../utils/utils.dart';
import 'onboarding_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _signIn(BuildContext context) {
    // This screen only ever appears before a profile exists on this
    // device, so there's nothing to sign into yet. Rather than push
    // a Lock Screen that has no PIN to check against, guide the
    // owner to Register first — Sign In will be the normal path on
    // every later app open once an account exists.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("No account on this device yet — tap Register to set one up."),
        backgroundColor: AppColors.primaryDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── App icon ────────────────────────────────
              Container(
                width: 96, height: 96,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/app_icon_mark.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'JavisAudit',
                style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Text(
                'Track income, expenses, sales and VAT — all on your device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14),
              ),

              const Spacer(flex: 3),

              // ── Register ────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  ),
                  child: const Text('Register', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 12),

              // ── Sign In ─────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => _signIn(context),
                  child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
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
