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

  String? _selectedBusinessType;
  bool _isSaving = false;

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
    _selectedBusinessType = profile?.businessType;
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
