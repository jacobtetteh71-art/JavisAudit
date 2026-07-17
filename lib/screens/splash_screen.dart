// ============================================================
// screens/splash_screen.dart  –  Step 1: Splash Screen
// ============================================================
// The very first screen the user sees when opening the app.
// While showing the logo, it checks the database:
//  • If no business profile exists → go to OnboardingScreen
//  • If a profile exists           → go to MainNavScreen
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../utils/utils.dart';
import 'onboarding_screen.dart';
import 'main_nav_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // AnimationController drives the fade-in of the logo
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Set up a 1-second fade-in animation for the logo
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this, // 'this' refers to the SingleTickerProvider mixin
    );

    // Tween: animate from 0.0 (invisible) to 1.0 (fully visible)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Start the animation and then navigate after 1.5 seconds total
    _controller.forward();
    _initApp();
  }

  // ── _initApp: load profile and navigate ───────────────────
  Future<void> _initApp() async {
    // Load the business profile from the database.
    // context.read<T>() gets the provider without rebuilding
    // (safe to use outside build())
    await context.read<ProfileProvider>().loadProfile();

    // Also pre-load the VAT turnover so the dashboard is ready
    await context.read<VatProvider>().loadTurnover();

    // Wait for the minimum splash duration (1.5 seconds total)
    await Future.delayed(const Duration(milliseconds: 1500));

    // Check if mounted before navigating — the widget might
    // have been disposed if the user closed the app quickly
    if (!mounted) return;

    final hasProfile = context.read<ProfileProvider>().hasProfile;

    // pushReplacement replaces the splash in the navigation stack
    // so the back button doesn't return to the splash screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            hasProfile ? const MainNavScreen() : const OnboardingScreen(),
      ),
    );
  }

  @override
  void dispose() {
    // Always dispose animation controllers to free memory
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Full-screen deep green background
      backgroundColor: AppColors.primaryDark,
      body: Center(
        // FadeTransition smoothly shows the logo during the splash
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── App Icon ──────────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.book_outlined, // Ledger book icon
                  size: 56,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // ── App Name ──────────────────────────────────
              const Text(
                'JavisAudit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // ── Tagline ───────────────────────────────────
              Text(
                'Smart Accounting for Every Business',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 48),

              // ── Loading indicator ─────────────────────────
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
