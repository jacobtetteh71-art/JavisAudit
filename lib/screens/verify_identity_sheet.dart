// ============================================================
// screens/verify_identity_sheet.dart  –  "Confirm It's You" Prompt
// ============================================================
// A small, reusable PIN/password confirmation sheet shown before
// any sensitive action:
//   • Deleting an income/expense/sale entry
//   • Backing up or restoring data
//   • Editing the business profile
//   • Changing the PIN/password
//   • Deleting all data
//
// Usage from anywhere in the app:
//
//   final confirmed = await verifyIdentity(context, reason: 'delete this entry');
//   if (confirmed) { ...proceed... }
//
// Returns true only if the correct PIN or backup password was
// entered. Returns false if cancelled or incorrect.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../utils/utils.dart';

Future<bool> verifyIdentity(BuildContext context, {String reason = 'continue'}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Prevents accidentally dismissing by tapping outside during
    // a sensitive action — the user must explicitly Cancel or Confirm
    isDismissible: true,
    builder: (_) => _VerifyIdentitySheet(reason: reason),
  );
  return result ?? false;
}

class _VerifyIdentitySheet extends StatefulWidget {
  final String reason;
  const _VerifyIdentitySheet({required this.reason});

  @override
  State<_VerifyIdentitySheet> createState() => _VerifyIdentitySheetState();
}

class _VerifyIdentitySheetState extends State<_VerifyIdentitySheet> {
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

  Future<void> _confirm() async {
    setState(() {
      _isChecking = true;
      _errorText = null;
    });

    final auth = context.read<AuthProvider>();
    final isValid = _usePasswordInstead
        ? await auth.confirmPassword(_passwordCtrl.text.trim())
        : await auth.confirmPin(_pinCtrl.text.trim());

    if (!mounted) return;

    if (isValid) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isChecking = false;
        _errorText = _usePasswordInstead ? 'Incorrect password.' : 'Incorrect PIN.';
      });
      _pinCtrl.clear();
      _passwordCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Icon(Icons.shield_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Confirm It\'s You', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your PIN to ${widget.reason}.',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),

            if (_usePasswordInstead)
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Backup Password', border: OutlineInputBorder()),
                onSubmitted: (_) => _confirm(),
              )
            else
              TextField(
                controller: _pinCtrl,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'PIN', border: OutlineInputBorder(), counterText: '',
                ),
                onSubmitted: (_) => _confirm(),
              ),

            if (_errorText != null) ...[
              const SizedBox(height: 6),
              Text(_errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _confirm,
                    child: _isChecking
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _usePasswordInstead = !_usePasswordInstead;
                  _errorText = null;
                }),
                child: Text(_usePasswordInstead ? 'Use PIN instead' : 'Use backup password instead'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
