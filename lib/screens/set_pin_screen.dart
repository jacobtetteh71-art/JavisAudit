// ============================================================
// screens/set_pin_screen.dart  –  First-time PIN + Password Setup
// ============================================================
// Shown right after Onboarding (or later from Settings, when the
// user wants to change their PIN/password). Collects:
//   • A 4–6 digit PIN — the everyday way to unlock the app
//   • A backup password — used only if the PIN is forgotten
//
// Both are hashed (never stored in plain text) via AuthProvider.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../utils/utils.dart';
import 'main_nav_screen.dart';

class SetPinScreen extends StatefulWidget {
  // When true, this screen is being opened from Settings to CHANGE
  // an existing PIN/password rather than set one up for the first time.
  // We only change the navigation behaviour on success — everything
  // else about the form is identical.
  final bool isChangingCredentials;

  const SetPinScreen({super.key, this.isChangingCredentials = false});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final success = await context
        .read<AuthProvider>()
        .setupCredentials(_pinCtrl.text.trim(), _passwordCtrl.text.trim());

    setState(() => _isSaving = false);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isChangingCredentials
              ? 'PIN and password updated successfully!'
              : 'Your app is now protected!'),
          backgroundColor: AppColors.primary,
        ),
      );

      if (widget.isChangingCredentials) {
        // Came from Settings — just go back there
        Navigator.of(context).pop();
      } else {
        // First-time setup — go straight into the app
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavScreen()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isChangingCredentials ? 'Change PIN & Password' : 'Secure Your App'),
        // No back button on first-time setup — it can't be skipped
        automaticallyImplyLeading: widget.isChangingCredentials,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isChangingCredentials
                          ? 'Set a new PIN & password 🔒'
                          : 'Protect your business data 🔒',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This PIN will be required every time you open the app. '
                      'The backup password can unlock the app if you ever forget your PIN.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('Create a PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),

              TextFormField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: '4–6 Digit PIN *',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (val) {
                  if (val == null || val.length < 4 || val.length > 6) {
                    return 'PIN must be 4–6 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _confirmPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN *',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (val) {
                  if (val != _pinCtrl.text) return 'PINs do not match';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              const Text('Backup Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              const Text(
                'Used only if you forget your PIN — make it something memorable.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password *', border: OutlineInputBorder()),
                validator: (val) {
                  if (val == null || val.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _confirmPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm Password *', border: OutlineInputBorder()),
                validator: (val) {
                  if (val != _passwordCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.isChangingCredentials ? 'Update PIN & Password' : 'Save & Enter App'),
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
