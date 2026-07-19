// ============================================================
// screens/business_documents_screen.dart  –  Advanced: Business Documents
// ============================================================
// An "Advanced" Settings feature that lets a business owner attach
// PDF copies of certificates and licenses they commonly need on
// hand when applying for a tender or bid — e.g. Certificate of
// Incorporation, SSNIT Clearance, an operating license/permit.
//
// Each document type is stored as a single row keyed by its type,
// so re-attaching a document simply replaces the previous copy.
// The PDF itself is copied into the app's own documents folder
// (not just referenced at its original, possibly temporary, path).
// ============================================================

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../database/database_helper.dart';
import '../utils/utils.dart';

// A standard, reusable document type a business may need on hand
// for bid/tender applications. Deliberately excludes the GRA Tax
// Clearance Certificate, since that already has its own place
// under VAT/Tax records elsewhere in the app.
class _DocType {
  final String key;
  final String label;
  final String description;
  final IconData icon;

  const _DocType(this.key, this.label, this.description, this.icon);
}

const List<_DocType> _documentTypes = [
  _DocType(
    'certificate_of_incorporation',
    'Certificate of Incorporation',
    'Proof your business is registered as a legal entity.',
    Icons.workspace_premium_outlined,
  ),
  _DocType(
    'business_registration_certificate',
    'Business Registration Certificate',
    'Registrar General\'s Department registration (Forms 3 & B).',
    Icons.badge_outlined,
  ),
  _DocType(
    'ssnit_clearance_certificate',
    'SSNIT Clearance Certificate',
    'Confirms staff pension contributions are up to date.',
    Icons.verified_user_outlined,
  ),
  _DocType(
    'vat_registration_certificate',
    'VAT Registration Certificate',
    'Shows your business is registered for VAT (if applicable).',
    Icons.receipt_long_outlined,
  ),
  _DocType(
    'operating_license',
    'Operating License / Permit',
    'Your license or permit to legally operate in your sector.',
    Icons.storefront_outlined,
  ),
  _DocType(
    'ppa_supplier_certificate',
    'PPA Supplier Registration Certificate',
    'Public Procurement Authority supplier/contractor registration.',
    Icons.gavel_outlined,
  ),
  _DocType(
    'other_supporting_document',
    'Other Supporting Document',
    'Any other certificate a procurement entity may request.',
    Icons.description_outlined,
  ),
];

class BusinessDocumentsScreen extends StatefulWidget {
  const BusinessDocumentsScreen({super.key});

  @override
  State<BusinessDocumentsScreen> createState() => _BusinessDocumentsScreenState();
}

class _BusinessDocumentsScreenState extends State<BusinessDocumentsScreen> {
  // doc_type -> saved row (file_name, file_path, uploaded_at)
  Map<String, Map<String, dynamic>> _saved = {};
  bool _loading = true;
  String? _busyKey; // doc_type currently being attached/removed

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DatabaseHelper.instance.getBusinessDocuments();
    if (!mounted) return;
    setState(() {
      _saved = {for (var r in rows) r['doc_type'] as String: r};
      _loading = false;
    });
  }

  // ── _attach: pick a PDF, copy it in, save the DB record ─────
  Future<void> _attach(_DocType type) async {
    setState(() => _busyKey = type.key);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.single.path == null) {
        setState(() => _busyKey = null);
        return;
      }

      final pickedPath = result.files.single.path!;
      final originalName = result.files.single.name;

      // Copy into a stable folder inside the app's own documents
      // directory, named after the doc type so re-attaching cleanly
      // replaces the previous file rather than piling up copies.
      final docsDir = await getApplicationDocumentsDirectory();
      final folder = Directory('${docsDir.path}/business_documents');
      if (!await folder.exists()) await folder.create(recursive: true);

      final savedPath = '${folder.path}/${type.key}.pdf';
      await File(pickedPath).copy(savedPath);

      await DatabaseHelper.instance.upsertBusinessDocument({
        'doc_type': type.key,
        'file_name': originalName,
        'file_path': savedPath,
        'uploaded_at': DateTime.now().toIso8601String(),
      });

      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${type.label} attached.'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach document: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  // ── _view: open the saved PDF in the printing package's viewer ─
  Future<void> _view(Map<String, dynamic> doc) async {
    try {
      final bytes = await File(doc['file_path'] as String).readAsBytes();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: doc['file_name'] as String,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── _remove: delete the file and its DB record ──────────────
  Future<void> _remove(_DocType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${type.label}?'),
        content: const Text('This document will be removed from JavisAudit. You can attach a new copy any time.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyKey = type.key);
    try {
      final doc = _saved[type.key];
      if (doc != null) {
        final file = File(doc['file_path'] as String);
        if (await file.exists()) await file.delete();
      }
      await DatabaseHelper.instance.deleteBusinessDocument(type.key);
      await _load();
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Business Documents')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Keep PDF copies of certificates and licenses on hand — these are '
                    'commonly requested when applying for a tender or bid in Ghana. '
                    'Files stay on this device only.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 16),
                ..._documentTypes.map((type) => _documentTile(type)),
              ],
            ),
    );
  }

  Widget _documentTile(_DocType type) {
    final doc = _saved[type.key];
    final isAttached = doc != null;
    final isBusy = _busyKey == type.key;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: (isAttached ? AppColors.primary : AppColors.textMuted).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(type.icon, color: isAttached ? AppColors.primary : AppColors.textMuted, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(type.description, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    if (isAttached) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              doc['file_name'] as String,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isBusy)
            const Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 18, width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isAttached) ...[
                  TextButton.icon(
                    onPressed: () => _view(doc),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('View'),
                  ),
                  TextButton.icon(
                    onPressed: () => _remove(type),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: () => _attach(type),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
                  icon: const Icon(Icons.upload_file_outlined, size: 16),
                  label: Text(isAttached ? 'Replace' : 'Attach PDF'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
