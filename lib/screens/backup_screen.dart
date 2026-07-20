// ============================================================
// screens/backup_screen.dart  –  Step 11: Backup & Restore
// ============================================================
// Exports all 5 tables as one JSON file (shared via Android's
// native share sheet) and restores from a previously exported
// JSON file selected via the system file picker.
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import '../utils/csv_exporter.dart';
import 'verify_identity_sheet.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  Map<String, int> _counts = {};
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  // ── _loadCounts: show how many records exist in each table ──
  Future<void> _loadCounts() async {
    setState(() => _isLoading = true);
    final counts = await DatabaseHelper.instance.getRecordCounts();
    if (!mounted) return;
    setState(() {
      _counts = counts;
      _isLoading = false;
    });
  }

  // ── _exportBackup ─────────────────────────────────────────
  Future<void> _exportBackup() async {
    // Exporting shares all financial data outside the app —
    // confirm identity first
    final verified = await verifyIdentity(context, reason: 'export a backup');
    if (!verified || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      // Step 1: Pull all data from every table as a nested Map
      final data = await DatabaseHelper.instance.exportAllData();

      // Step 2: Convert the Map into a JSON string.
      // JsonEncoder.withIndent makes it human-readable (pretty-printed)
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      // Step 3: Write the JSON string to a temporary file.
      // getTemporaryDirectory() gives a cache folder the OS can clean up
      final dir = await getTemporaryDirectory();
      final dateStr = AppFormat.today().replaceAll('-', '');
      final file = File('${dir.path}/javisaudit_backup_$dateStr.json');
      await file.writeAsString(jsonString);

      // Step 4: Open the Android share sheet so the user can save
      // the file to Drive, send via WhatsApp, email it, etc.
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'JavisAudit backup — ${AppFormat.displayDate(AppFormat.today())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup exported successfully!'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── _restoreBackup ────────────────────────────────────────
  Future<void> _restoreBackup() async {
    // Step 1: Two-step confirmation — this is a DESTRUCTIVE action
    final confirmed = await _confirmRestore();
    if (!confirmed) return;
    if (!mounted) return;

    // Step 1b: Confirm identity before this destructive action proceeds
    final verified = await verifyIdentity(context, reason: 'restore from backup');
    if (!verified || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      // Step 2: Open the system file picker, restricted to .json files
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      // User cancelled the picker
      if (result == null || result.files.single.path == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // Step 3: Read and parse the selected file
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Step 4: Validate the structure — must contain all expected keys
      final requiredKeys = ['business_profile', 'income', 'expenses', 'sales'];
      final isValid = requiredKeys.every((key) => data.containsKey(key));
      if (!isValid) {
        throw Exception('Invalid backup file format.');
      }

      // Step 5: Wipe existing data and re-insert from the backup
      await DatabaseHelper.instance.restoreFromBackup(data);

      // Step 6: Refresh the on-screen record counts
      await _loadCounts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data restored successfully! Please restart the app.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── _confirmRestore: two-step "are you sure?" dialog ────────
  Future<bool> _confirmRestore() async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Restore from Backup?'),
        content: const Text(
          'This will PERMANENTLY DELETE all current data on this device and '
          'replace it with the data from your selected backup file.',
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

    if (firstConfirm != true) return false;
    if (!mounted) return false;

    // Second confirmation — must type the word DELETE to proceed
    final controller = TextEditingController();
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type DELETE below to confirm this action:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim().toUpperCase() == 'DELETE'),
            child: const Text('Confirm Restore', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return secondConfirm == true;
  }

  // ── _exportCsv: CSV export for one record type ─────────────
  Future<void> _exportCsv(String type) async {
    final verified = await verifyIdentity(context, reason: 'export data to CSV');
    if (!verified || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      switch (type) {
        case 'income':
          final rows = await DatabaseHelper.instance.getAllIncome();
          await exportIncomeToCsv(rows.map((r) => Income.fromMap(r)).toList());
          break;
        case 'expenses':
          final rows = await DatabaseHelper.instance.getAllExpenses();
          await exportExpensesToCsv(rows.map((r) => Expense.fromMap(r)).toList());
          break;
        case 'sales':
          final rows = await DatabaseHelper.instance.getAllSales();
          await exportSalesToCsv(rows.map((r) => Sale.fromMap(r)).toList());
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV exported!'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Export card ────────────────────────────
                _actionCard(
                  icon: Icons.upload_file,
                  iconColor: AppColors.primary,
                  title: 'Export Backup',
                  description:
                      'Save all your data as a JSON file. Share it to WhatsApp, '
                      'email, or Google Drive to keep it safe.',
                  buttonLabel: 'Export Now',
                  buttonColor: AppColors.primary,
                  onPressed: _isProcessing ? null : _exportBackup,
                ),
                const SizedBox(height: 14),

                // ── Restore card ───────────────────────────
                _actionCard(
                  icon: Icons.download_outlined,
                  iconColor: AppColors.expense,
                  title: 'Restore from Backup',
                  description:
                      'Replace ALL current data with a previously exported '
                      'backup file. This cannot be undone.',
                  buttonLabel: 'Choose Backup File',
                  buttonColor: AppColors.expense,
                  onPressed: _isProcessing ? null : _restoreBackup,
                ),
                const SizedBox(height: 14),

                // ── CSV export card ────────────────────────
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
                        children: const [
                          Icon(Icons.table_chart_outlined, color: AppColors.info),
                          SizedBox(width: 8),
                          Text('Export to CSV / Excel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Share a spreadsheet-ready file for your accountant — opens in '
                        'Excel, Google Sheets, or any spreadsheet app.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isProcessing ? null : () => _exportCsv('income'),
                              child: const Text('Income', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isProcessing ? null : () => _exportCsv('expenses'),
                              child: const Text('Expenses', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isProcessing ? null : () => _exportCsv('sales'),
                              child: const Text('Sales', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Current data summary ───────────────────
                const Text('Current Data on This Device',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _countRow('Business Profile', _counts['business_profile'] ?? 0),
                      _countRow('Income Records', _counts['income'] ?? 0),
                      _countRow('Expense Records', _counts['expenses'] ?? 0),
                      _countRow('Sales Records', _counts['sales'] ?? 0),
                    ],
                  ),
                ),

                if (_isProcessing) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String buttonLabel,
    required Color buttonColor,
    required VoidCallback? onPressed,
  }) {
    return Container(
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
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: buttonColor),
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
