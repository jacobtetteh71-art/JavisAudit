// ============================================================
// utils/csv_exporter.dart  –  CSV Export for Income/Expenses/Sales
// ============================================================
// Builds a CSV file (readable by Excel, Google Sheets, or any
// spreadsheet tool) from the app's records, and shares it via the
// Android share sheet — the same way backups and PDFs are shared.
// ============================================================

import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import 'utils.dart';

Future<void> exportIncomeToCsv(List<Income> records) async {
  final rows = <List<dynamic>>[
    ['Date', 'Description', 'Category', 'Amount (GHS)', 'Payment Method', 'Notes'],
    ...records.map((r) => [
          r.date,
          r.description,
          r.category,
          AppFormat.amount(r.amount),
          r.paymentMethod,
          r.notes ?? '',
        ]),
  ];
  await _shareCsv(rows, 'JavisAudit_Income');
}

Future<void> exportExpensesToCsv(List<Expense> records) async {
  final rows = <List<dynamic>>[
    ['Date', 'Description', 'Category', 'Amount (GHS)', 'Payment Method', 'Status', 'Amount Paid', 'Balance'],
    ...records.map((r) => [
          r.date,
          r.description,
          r.category,
          AppFormat.amount(r.amount),
          r.paymentMethod,
          r.paymentStatus,
          AppFormat.amount(r.amountPaid),
          AppFormat.amount(r.balance),
        ]),
  ];
  await _shareCsv(rows, 'JavisAudit_Expenses');
}

Future<void> exportSalesToCsv(List<Sale> records) async {
  final rows = <List<dynamic>>[
    [
      'Date', 'Customer', 'Item', 'Quantity', 'Unit Price', 'Total Amount (GHS)',
      'Payment Method', 'Status', 'Amount Paid', 'Balance',
    ],
    ...records.map((r) => [
          r.date,
          r.customerName ?? '',
          r.itemDescription,
          r.quantity,
          AppFormat.amount(r.unitPrice),
          AppFormat.amount(r.totalAmount),
          r.paymentMethod,
          r.paymentStatus,
          AppFormat.amount(r.amountPaid),
          AppFormat.amount(r.balance),
        ]),
  ];
  await _shareCsv(rows, 'JavisAudit_Sales');
}

Future<void> _shareCsv(List<List<dynamic>> rows, String baseFilename) async {
  final csvString = const ListToCsvConverter().convert(rows);

  final tempDir = await getTemporaryDirectory();
  final today = AppFormat.today();
  final file = File('${tempDir.path}/${baseFilename}_$today.csv');
  await file.writeAsString(csvString);

  await Share.shareXFiles([XFile(file.path)], subject: baseFilename.replaceAll('_', ' '));
}
