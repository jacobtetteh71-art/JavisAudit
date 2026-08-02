// ============================================================
// screens/welcome_screen.dart  –  First-Launch Welcome Screen
// ============================================================
// Shown once, the very first time the app is opened (before any
// business profile exists). A modern pill toggle switches between
// two sliding panels:
//   • Create Account — the common path for a brand-new business.
//     Continuing slides the NEXT screen in from the right (feels
//     like moving forward) into the Onboarding wizard.
//   • Sign In — for someone who already has a Cloud Sync account
//     (see services/sync_service.dart) and is setting up JavisAudit
//     on a new or replacement phone. Signing in here actually pulls
//     their business data down from the cloud — this is a real
//     restore, not a placeholder. Continuing slides the NEXT screen
//     in from the left (feels like returning to something that
//     already exists) into the Lock Screen, where their existing
//     PIN — restored along with everything else — unlocks the app.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../services/sync_service.dart';
import '../utils/utils.dart';
import '../utils/page_transitions.dart';
import 'lock_screen.dart';
import 'onboarding_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pageController = PageController();
  int _tabIndex = 0; // 0 = Create Account, 1 = Sign In

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isSigningIn = false;
  String? _signInError;

  @override
  void dispose() {
    _pageController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _tabIndex) return;
    setState(() {
      _tabIndex = index;
      _signInError = null;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToCreateAccount() {
    // Moving FORWARD into the app for the first time — the new
    // screen sweeps in from the right.
    Navigator.of(context).pushReplacement(
      slideFromRight(const OnboardingScreen()),
    );
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _signInError = 'Enter the email you used for Cloud Sync.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _signInError = 'Enter your Cloud Sync password.');
      return;
    }

    setState(() {
      _isSigningIn = true;
      _signInError = null;
    });

    final sync = context.read<SyncProvider>();
    final signedIn = await sync.signIn(email, password);
    if (!mounted) return;

    if (!signedIn) {
      setState(() {
        _isSigningIn = false;
        _signInError = sync.errorMessage ?? 'Could not sign in. Please try again.';
      });
      return;
    }

    // Pull the account's data down onto this device. This is a
    // brand-new phone with nothing on it yet, so — unlike a routine
    // sync between two devices that both already have data — there's
    // no real ambiguity about which copy to keep. If SyncService
    // still raises a conflict (both sides look "unsynced" simply
    // because this device has never synced before), the cloud copy
    // is unambiguously the one worth keeping here.
    try {
      await SyncService.instance.syncNow();
    } on SyncConflictException {
      await SyncService.instance.resolveConflict(keepLocal: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _signInError = 'Signed in, but could not restore your data. Check your connection and try again.';
      });
      return;
    }

    if (!mounted) return;

    // Refresh every provider that reads from the database, now that
    // restoreFromBackup() has repopulated it from the cloud snapshot —
    // including the owner's existing PIN, which travels with the rest
    // of the business data (see database_helper.dart's `settings` table).
    await context.read<ProfileProvider>().loadProfile();
    await context.read<AuthProvider>().loadAuthStatus();
    await context.read<VatProvider>().loadTurnover();

    if (!mounted) return;
    setState(() => _isSigningIn = false);

    // Moving BACK into an existing account — the new screen sweeps
    // in from the left. Their restored PIN unlocks it from here,
    // exactly like every other app open.
    Navigator.of(context).pushAndRemoveUntil(
      slideFromLeft(const LockScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // ── App icon + name ───────────────────────────
              Container(
                width: 76, height: 76,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.asset('assets/app_icon_mark.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'JavisAudit',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 6),
              Text(
                'Track income, expenses, sales and VAT — all on your device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
              ),
              const SizedBox(height: 28),

              // ── Pill toggle ───────────────────────────────
              _buildPillToggle(),
              const SizedBox(height: 24),

              // ── Sliding content ───────────────────────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, -6)),
                    ],
                  ),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(), // deliberate, tab-driven only
                    onPageChanged: (index) => setState(() => _tabIndex = index),
                    children: [
                      _buildCreateAccountPanel(),
                      _buildSignInPanel(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── The sliding-indicator segmented control ─────────────────
  Widget _buildPillToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: _tabIndex == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 42,
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(26)),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: _pillTab('Create Account', 0)),
              Expanded(child: _pillTab('Sign In', 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillTab(String label, int index) {
    final isSelected = _tabIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () => _selectTab(index),
      child: SizedBox(
        height: 42,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.75),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }

  // ── Panel 1: Create Account ──────────────────────────────────
  Widget _buildCreateAccountPanel() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Set up your business', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'A few quick steps to record your business details and protect '
            'them with a PIN. Everything stays on this device unless you '
            'turn on Cloud Sync later.',
            style: TextStyle(fontSize: 13.5, color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 28),
          _bulletRow(Icons.business_outlined, 'Tell us about your business'),
          _bulletRow(Icons.lock_outline, 'Choose a PIN to keep it private'),
          _bulletRow(Icons.check_circle_outline, 'Start recording income & expenses'),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: _goToCreateAccount,
              child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  // ── Panel 2: Sign In (Facebook-style entry fields) ──────────
  Widget _buildSignInPanel() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sign in to restore your account', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Already using JavisAudit with Cloud Sync on another phone? '
            'Sign in with that account to bring your business data — and '
            'your PIN — onto this device.',
            style: TextStyle(fontSize: 13.5, color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 24),

          // Rounded, filled, icon-prefixed fields — the Facebook-style
          // entry treatment: soft grey fill, no visible border, large
          // touch target, generous internal padding.
          _softField(
            controller: _emailCtrl,
            hint: 'Email',
            icon: Icons.alternate_email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _softField(
            controller: _passwordCtrl,
            hint: 'Password',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20, color: AppColors.textMuted),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            onSubmitted: (_) => _signIn(),
          ),

          if (_signInError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.expenseLight, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppColors.expense),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_signInError!, style: const TextStyle(fontSize: 12, color: AppColors.expense))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: _isSigningIn ? null : _signIn,
              child: _isSigningIn
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _selectTab(0),
              child: const Text(
                "Don't have Cloud Sync set up? Create an account instead.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 14.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textLight),
          prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        ),
      ),
    );
  }
}
