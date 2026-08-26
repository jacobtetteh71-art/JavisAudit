// ============================================================
// screens/settings_screen.dart  –  Step 11: Settings
// ============================================================
// Lets the user update their business profile after onboarding
// (using UPDATE instead of INSERT) and includes the destructive
// "Delete All Data" action with strong confirmation safeguards.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'onboarding_screen.dart';
import 'set_pin_screen.dart';
import 'verify_identity_sheet.dart';
import 'business_documents_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _businessNameCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _graTinCtrl;
  late TextEditingController _vatNumberCtrl;
  late TextEditingController _paymentDetailsCtrl;
  late TextEditingController _digitalAddressCtrl;

  String? _selectedBusinessType;
  bool _isSaving = false;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill all fields with the CURRENT profile data.
    // This is the key difference from the Onboarding screen,
    // which always starts blank.
    final profile = context.read<ProfileProvider>().profile;

    _businessNameCtrl = TextEditingController(text: profile?.businessName ?? '');
    _ownerNameCtrl    = TextEditingController(text: profile?.ownerName ?? '');
    _phoneCtrl        = TextEditingController(text: profile?.phone ?? '');
    _emailCtrl        = TextEditingController(text: profile?.email ?? '');
    _locationCtrl     = TextEditingController(text: profile?.location ?? '');
    _graTinCtrl       = TextEditingController(text: profile?.graTin ?? '');
    _vatNumberCtrl    = TextEditingController(text: profile?.vatNumber ?? '');
    _paymentDetailsCtrl = TextEditingController(text: profile?.paymentDetails ?? '');
    _digitalAddressCtrl = TextEditingController(text: profile?.digitalAddress ?? '');
    _selectedBusinessType = profile?.businessType;

    // Business/owner contact details, GRA TIN, and VAT number are
    // sensitive — the fields above are pre-filled immediately, so
    // gate the whole screen behind a PIN/password check before it's
    // ever shown, rather than only checking before saving changes.
    WidgetsBinding.instance.addPostFrameCallback((_) => _authorize());
  }

  Future<void> _authorize() async {
    final verified = await verifyIdentity(context, reason: 'view and update the business profile');
    if (!mounted) return;
    if (!verified) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isAuthorized = true);
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _locationCtrl.dispose();
    _graTinCtrl.dispose();
    _vatNumberCtrl.dispose();
    _paymentDetailsCtrl.dispose();
    _digitalAddressCtrl.dispose();
    super.dispose();
  }

  // ── _save: UPDATE the existing profile row ───────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBusinessType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a business type.'), backgroundColor: Colors.red),
      );
      return;
    }

    // Confirm it's really the account owner making this change,
    // before committing the update
    final verified = await verifyIdentity(context, reason: 'update the business profile');
    if (!verified || !mounted) return;

    setState(() => _isSaving = true);

    final existingProfile = context.read<ProfileProvider>().profile;

    final updated = BusinessProfile(
      id:           existingProfile?.id,
      businessName: _businessNameCtrl.text.trim(),
      ownerName:    _ownerNameCtrl.text.trim(),
      businessType: _selectedBusinessType!,
      phone:        _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email:        _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      location:     _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      graTin:       _graTinCtrl.text.trim().isEmpty ? null : _graTinCtrl.text.trim(),
      vatNumber:    _vatNumberCtrl.text.trim().isEmpty ? null : _vatNumberCtrl.text.trim(),
      paymentDetails: _paymentDetailsCtrl.text.trim().isEmpty ? null : _paymentDetailsCtrl.text.trim(),
      digitalAddress: _digitalAddressCtrl.text.trim().isEmpty ? null : _digitalAddressCtrl.text.trim(),
      // Preserve the original creation timestamp — only updatedAt changes
      createdAt:    existingProfile?.createdAt ?? DateTime.now().toIso8601String(),
    );

    final success = await context.read<ProfileProvider>().updateProfile(updated);

    setState(() => _isSaving = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Profile updated successfully!' : 'Update failed. Try again.'),
        backgroundColor: success ? AppColors.primary : Colors.red,
      ),
    );
  }

  // ── _deleteAllData: the nuclear option ────────────────────
  Future<void> _deleteAllData() async {
    // First warning dialog
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Delete All Data?'),
        content: const Text(
          'This will permanently delete EVERY income, expense, and sales record, '
          'plus your business profile. We strongly recommend exporting a backup '
          'first from the Backup & Restore screen.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !mounted) return;

    // Second, type-to-confirm dialog
    final controller = TextEditingController();
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Type DELETE to confirm'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim().toUpperCase() == 'DELETE'),
            child: const Text('Delete Everything', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (secondConfirm != true || !mounted) return;

    // Final gate: confirm PIN/password before this irreversible
    // action actually goes through
    final verified = await verifyIdentity(context, reason: 'delete all data');
    if (!verified || !mounted) return;

    // Perform the deletion
    await DatabaseHelper.instance.deleteAllData();

    if (!mounted) return;

    // Send the user back to Onboarding since there's no profile anymore
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false, // remove ALL previous routes from the stack
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Business Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),

              TextFormField(
                controller: _businessNameCtrl,
                decoration: const InputDecoration(labelText: 'Business Name *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a business name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerNameCtrl,
                decoration: const InputDecoration(labelText: 'Owner Name *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter the owner name' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedBusinessType,
                decoration: const InputDecoration(labelText: 'Business Type *', border: OutlineInputBorder()),
                items: BusinessProfile.businessTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedBusinessType = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(labelText: 'Location / Region', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _graTinCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'GRA TIN', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vatNumberCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'VAT Number (if registered)', border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _paymentDetailsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Payment Details (for Invoices)',
                  hintText: 'e.g., MTN MoMo: 024-XXX-XXXX (Business Name)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _digitalAddressCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'GhanaPost GPS Digital Address (optional)',
                  hintText: 'e.g., GA-039-5028',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update Profile'),
                ),
              ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 12),

              // ── Advanced section ───────────────────────────
              const Text('Advanced', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attach PDF copies of certificates and licenses — such as your '
                      'Certificate of Incorporation or operating license — so they\'re '
                      'ready whenever you need to apply for a tender or bid.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const BusinessDocumentsScreen()),
                          );
                        },
                        icon: const Icon(Icons.folder_copy_outlined),
                        label: const Text('Business Documents'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),

              // ── Security section ───────────────────────────
              const Text('Security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update the PIN and backup password used to unlock this app.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        onPressed: () async {
                          // Must prove you're the current owner before
                          // you're allowed to set a NEW PIN/password
                          final verified =
                              await verifyIdentity(context, reason: 'change your PIN & password');
                          if (!verified || !context.mounted) return;

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SetPinScreen(isChangingCredentials: true),
                            ),
                          );
                        },
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Change PIN & Password'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _BiometricToggleTile(),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),

              // ── Danger zone ────────────────────────────────
              const Text('Danger Zone', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Permanently delete all business data from this device. '
                      'This action cannot be undone.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: _deleteAllData,
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Delete All Data'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Biometric unlock toggle ─────────────────────────────────
// A small self-contained widget (rather than plain settings-screen
// state) because it needs its own one-time async check of whether
// THIS device actually offers usable biometrics — no point showing
// a toggle for something the hardware/enrollment can't support.
class _BiometricToggleTile extends StatefulWidget {
  const _BiometricToggleTile();

  @override
  State<_BiometricToggleTile> createState() => _BiometricToggleTileState();
}

class _BiometricToggleTileState extends State<_BiometricToggleTile> {
  bool? _available; // null while checking

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final available = await context.read<AuthProvider>().isBiometricAvailable();
    if (mounted) setState(() => _available = available);
  }

  Future<void> _onToggle(bool wantsEnabled) async {
    final auth = context.read<AuthProvider>();
    if (wantsEnabled) {
      final success = await auth.enableBiometric();
      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not verify your fingerprint/face — please try again.')),
        );
      }
    } else {
      await auth.disableBiometric();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_available == false) return const SizedBox.shrink(); // no usable hardware — nothing to show

    final auth = context.watch<AuthProvider>();
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: const Text('Fingerprint / Face unlock', style: TextStyle(fontSize: 14)),
      subtitle: const Text(
        'Use your fingerprint or face as an alternative to typing your PIN.',
        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
      value: _available == null ? false : auth.isBiometricEnabled,
      onChanged: _available == null ? null : _onToggle,
      activeColor: AppColors.primary,
    );
  }
}
