// ============================================================
// screens/sync_screen.dart  –  Online (Cloud) Sync
// ============================================================
// Lets the business owner:
//   1. Create (or sign in to) a Cloud Sync account — separate
//      from the local PIN lock, since this identifies THEM
//      across devices rather than just unlocking one phone.
//   2. Tap "Sync Now" to push/pull their ledger to/from the cloud.
//   3. Resolve a conflict if both this device and the cloud
//      changed since the last successful sync.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../utils/utils.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // true = showing the "Create Account" form, false = "Sign In"
  bool _isCreatingAccount = false;
  bool _obscurePassword = true;
  bool _submitting = false;

  // Guards against re-showing the conflict dialog on every rebuild
  bool _conflictDialogShowing = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuthForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final sync = context.read<SyncProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = _isCreatingAccount
        ? await sync.signUp(email, password)
        : await sync.signIn(email, password);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      _passwordController.clear();
      // Kick off a first sync right away so the owner sees
      // something happen immediately after signing in.
      context.read<SyncProvider>().syncNow();
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _submitting = true);
    final sync = context.read<SyncProvider>();
    final isNewUser = await sync.signInWithGoogle();
    if (!mounted) return;
    setState(() => _submitting = false);

    if (isNewUser != null) {
      // Success — whether this Google account is brand-new to Cloud
      // Sync or already has data from another device, syncNow()'s
      // existing conflict-resolution flow (already wired into this
      // screen — see _conflictDialogShowing) handles reconciling it
      // against whatever's on this device, exactly like the
      // email/password path above.
      _passwordController.clear();
      context.read<SyncProvider>().syncNow();
    }
    // isNewUser == null means either a real failure (sync.errorMessage
    // is now set and displays automatically below) or the person just
    // closed the Google account picker — nothing further to do either way.
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out of Cloud Sync?'),
        content: const Text(
          'This only signs you out of the sync account. All your data '
          'stays safely on this device — it just won\'t sync to the '
          'cloud until you sign in again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<SyncProvider>().signOut();
    }
  }

  // ── The "both sides changed" conflict dialog ────────────────
  Future<void> _showConflictDialog(SyncProvider sync) async {
    if (_conflictDialogShowing) return;
    _conflictDialogShowing = true;

    final conflict = sync.pendingConflict!;
    final choice = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Which copy should we keep?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This device and your cloud backup have both changed since '
              'the last sync. Choose which one to keep — the other will '
              'be overwritten.',
            ),
            const SizedBox(height: 16),
            _conflictRow('This device, last changed', conflict.localModifiedAt),
            const SizedBox(height: 6),
            _conflictRow('Cloud copy, last changed', conflict.cloudModifiedAt),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Cloud Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keep This Device'),
          ),
        ],
      ),
    );

    _conflictDialogShowing = false;
    if (choice == null) {
      sync.dismissConflict();
      return;
    }
    if (!mounted) return;
    await sync.resolveConflict(keepLocal: choice);
  }

  Widget _conflictRow(String label, DateTime time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
        Text(
          AppFormat.displayDate(time.toIso8601String().split('T').first),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();

    if (sync.pendingConflict != null && !_conflictDialogShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showConflictDialog(sync));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Cloud Sync')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            sync.isSignedIn ? _signedInView(sync) : _signInFormView(sync),
          ],
        ),
      ),
    );
  }

  // ── Shown once signed in to a Cloud Sync account ────────────
  Widget _signedInView(SyncProvider sync) {
    final lastSynced = sync.lastSyncedAt;
    final lastSyncedLabel = lastSynced == null
        ? 'Never synced yet'
        : 'Last synced ${AppFormat.displayDate(lastSynced.toIso8601String().split('T').first)} '
            'at ${TimeOfDay.fromDateTime(lastSynced).format(context)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_done_outlined, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sync.currentUser?.email ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(lastSyncedLabel, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: sync.isSyncing ? null : () => sync.syncNow(),
                  icon: sync.isSyncing
                      ? const SizedBox(
                          height: 16, width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync),
                  label: Text(sync.isSyncing ? 'Syncing…' : 'Sync Now'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: sync.isSyncing ? null : _confirmSignOut,
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.expense),
                  child: const Text('Sign Out of Cloud Sync'),
                ),
              ),
            ],
          ),
        ),
        if (sync.errorMessage != null) ...[
          const SizedBox(height: 14),
          _errorBanner(sync.errorMessage!),
        ],
        const SizedBox(height: 20),
        _howItWorksCard(),
      ],
    );
  }

  // ── Shown when signed out ───────────────────────────────────
  Widget _signInFormView(SyncProvider sync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_outlined, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      _isCreatingAccount ? 'Create a Sync Account' : 'Sign In to Sync',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Back up your ledger to the cloud and pick up right where '
                  'you left off on a new or replacement phone.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your email';
                    if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
                if (!_isCreatingAccount) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _submitting ? null : _handleForgotPassword,
                      child: const Text('Forgot password?', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitAuthForm,
                    child: _submitting
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isCreatingAccount ? 'Create Account & Sync' : 'Sign In'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('OR', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _continueWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 26),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _isCreatingAccount = !_isCreatingAccount),
                    child: Text(
                      _isCreatingAccount
                          ? 'Already have a sync account? Sign in'
                          : 'New here? Create a sync account',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (sync.errorMessage != null) ...[
          const SizedBox(height: 14),
          _errorBanner(sync.errorMessage!),
        ],
        const SizedBox(height: 20),
        _howItWorksCard(),
      ],
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email above first')),
      );
      return;
    }
    final sent = await context.read<SyncProvider>().sendPasswordReset(email);
    if (!mounted) return;
    if (sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email')),
      );
    }
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.expenseLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.expense.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.expense, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5, color: AppColors.expense))),
        ],
      ),
    );
  }

  Widget _howItWorksCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How Cloud Sync works', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          SizedBox(height: 8),
          Text(
            '• Your data still lives on this phone first — Cloud Sync is a backup, not a replacement.\n'
            '• Tap "Sync Now" any time you have internet to back up the newest changes.\n'
            '• Sign in with the same email on a new phone and sync to bring everything back.\n'
            '• If you edit records on two phones before syncing either one, JavisAudit will ask '
            'which copy to keep rather than guess.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
