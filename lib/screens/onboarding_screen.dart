// ============================================================
// screens/onboarding_screen.dart  –  Step 2: Business Setup
// ============================================================
// Shown ONLY on first launch when no profile exists.
// Collects business identity and saves it to the database.
// Cannot be skipped.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'set_pin_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // _formKey lets us validate all fields at once with _formKey.currentState!.validate()
  final _formKey = GlobalKey<FormState>();

  // TextEditingControllers hold the text the user types in each field.
  // We use controllers (instead of just reading the text) because we
  // need to clear them or pre-fill them later.
  final _businessNameCtrl  = TextEditingController();
  final _ownerNameCtrl     = TextEditingController();
  final _phoneCtrl         = TextEditingController();
  final _emailCtrl         = TextEditingController();
  final _locationCtrl      = TextEditingController();
  final _graTinCtrl        = TextEditingController();

  // The selected business type from the dropdown
  String? _selectedBusinessType;

  bool _isSaving = false; // Shows a loading spinner on the button

  @override
  void dispose() {
    // Dispose all controllers when the screen is removed from memory
    // Forgetting this causes memory leaks
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _locationCtrl.dispose();
    _graTinCtrl.dispose();
    super.dispose();
  }

  // ── _save: validate and write to database ─────────────────
  Future<void> _save() async {
    // validate() calls the validator on every FormField.
    // Returns false if any validator returns an error string.
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Build the BusinessProfile object from the form values
    final profile = BusinessProfile(
      businessName:  _businessNameCtrl.text.trim(),
      ownerName:     _ownerNameCtrl.text.trim(),
      businessType:  _selectedBusinessType!,
      phone:         _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email:         _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      location:      _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      graTin:        _graTinCtrl.text.trim().isEmpty ? null : _graTinCtrl.text.trim(),
      createdAt:     DateTime.now().toIso8601String(),
    );

    // Save to the database via the provider
    final success = await context.read<ProfileProvider>().saveProfile(profile);

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      // Show a brief success message (Snackbar)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business profile saved successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
      // Navigate to PIN setup — the app can't be used without
      // securing it first. SetPinScreen itself moves on to the
      // Dashboard once the PIN/password are saved.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SetPinScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save profile. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // ── AppBar ────────────────────────────────────────────
      appBar: AppBar(
        title: const Text('Set Up Your Business'),
        // No back button — this screen cannot be skipped
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header card ────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to JavisAudit! 👋',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tell us about your business. This information will '
                      'appear on your financial reports and PDF exports.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Required Fields Section ────────────────────
              _sectionTitle('Business Information'),
              const SizedBox(height: 12),

              // Business Name field
              _buildField(
                controller:  _businessNameCtrl,
                label:       'Business Name *',
                hint:        'e.g., Ama\'s Fashion Store',
                // validator runs when _formKey.currentState!.validate() is called
                validator: (val) {
                  if (val == null || val.trim().length < 2) {
                    return 'Enter a business name (min 2 characters)';
                  }
                  return null; // null means valid
                },
              ),
              const SizedBox(height: 12),

              // Owner Name field
              _buildField(
                controller: _ownerNameCtrl,
                label:      'Owner / Manager Name *',
                hint:       'e.g., Ama Mensah',
                validator: (val) {
                  if (val == null || val.trim().length < 2) {
                    return 'Enter the owner\'s name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Business Type dropdown
              DropdownButtonFormField<String>(
                value: _selectedBusinessType,
                decoration: const InputDecoration(
                  labelText: 'Business Type *',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Select business type'),
                items: BusinessProfile.businessTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedBusinessType = val),
                validator: (val) {
                  if (val == null) return 'Please select a business type';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Optional Fields Section ────────────────────
              _sectionTitle('Contact & Compliance (Optional)'),
              const SizedBox(height: 12),

              _buildField(
                controller: _phoneCtrl,
                label:      'Phone Number',
                hint:       '0241234567',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _emailCtrl,
                label:      'Email Address',
                hint:       'business@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller:  _locationCtrl,
                label:       'Location / Region',
                hint:        'e.g., Accra, Greater Accra',
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _graTinCtrl,
                label:      'GRA TIN (if registered)',
                hint:       'e.g., C0000000000',
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),

              // ── Save Button ────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save & Continue →'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper: section title widget ──────────────────────────
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  // ── Helper: consistent text field builder ─────────────────
  // Reduces repetition — we just call _buildField() instead of
  // writing a full TextFormField every time
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    return TextFormField(
      controller:         controller,
      keyboardType:       keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText:  hint,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}
