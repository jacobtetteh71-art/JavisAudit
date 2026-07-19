// ============================================================
// widgets/cheque_details_fields.dart  –  Optional Cheque Details
// ============================================================
// Shown on the Income, Expense, and Sales entry forms whenever the
// selected payment method is 'Cheque'. Lets the user optionally
// record the account number, account name, and cheque number, plus
// attach a photo of the cheque for future reference — all purely
// optional, since not every business keeps this on hand right away.
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/utils.dart';

// Holds the controllers + picked image path for one form. The
// screen that owns the form creates one of these, disposes it in
// its own dispose(), and reads chequeDetailsMap() when saving.
class ChequeDetailsController {
  final accountNumberCtrl = TextEditingController();
  final accountNameCtrl = TextEditingController();
  final chequeNumberCtrl = TextEditingController();
  String? imagePath;

  void dispose() {
    accountNumberCtrl.dispose();
    accountNameCtrl.dispose();
    chequeNumberCtrl.dispose();
  }

  // Pre-fill from an existing record (used on edit flows, if added later)
  void loadFrom({
    String? accountNumber,
    String? accountName,
    String? chequeNumber,
    String? imagePath,
  }) {
    accountNumberCtrl.text = accountNumber ?? '';
    accountNameCtrl.text = accountName ?? '';
    chequeNumberCtrl.text = chequeNumber ?? '';
    this.imagePath = imagePath;
  }

  // Values to merge into the record's toMap() before saving.
  // All null when nothing was entered — the columns stay empty.
  Map<String, dynamic> toMap() => {
        'cheque_account_number':
            accountNumberCtrl.text.trim().isEmpty ? null : accountNumberCtrl.text.trim(),
        'cheque_account_name':
            accountNameCtrl.text.trim().isEmpty ? null : accountNameCtrl.text.trim(),
        'cheque_number':
            chequeNumberCtrl.text.trim().isEmpty ? null : chequeNumberCtrl.text.trim(),
        'cheque_image_path': imagePath,
      };
}

class ChequeDetailsFields extends StatefulWidget {
  final ChequeDetailsController controller;
  const ChequeDetailsFields({super.key, required this.controller});

  @override
  State<ChequeDetailsFields> createState() => _ChequeDetailsFieldsState();
}

class _ChequeDetailsFieldsState extends State<ChequeDetailsFields> {
  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 75, maxWidth: 1200);
    if (picked == null) return;

    setState(() => widget.controller.imagePath = picked.path);
  }

  void _removeImage() => setState(() => widget.controller.imagePath = null);

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.controller.imagePath != null;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text('Cheque Details (optional)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.controller.accountNumberCtrl,
            decoration: const InputDecoration(
              labelText: 'Account Number', isDense: true, border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.controller.accountNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Account Name', isDense: true, border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.controller.chequeNumberCtrl,
            decoration: const InputDecoration(
              labelText: 'Cheque Number / Code', isDense: true, border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          if (hasImage)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(widget.controller.imagePath!),
                    width: double.infinity, height: 140, fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6, right: 6,
                  child: GestureDetector(
                    onTap: _removeImage,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_a_photo_outlined, size: 16),
              label: const Text('Attach Cheque Photo'),
            ),
        ],
      ),
    );
  }
}
