// ============================================================
// screens/audit_report_screen.dart  –  Step 10: Year-End Audit
// ============================================================
// Generates a formal, multi-page PDF audit report for a chosen
// year using the `pdf` package, then opens the Android share
// sheet (via `printing`) so the user can save or send it.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/database_helper.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';

class AuditReportScreen extends StatefulWidget {
  const AuditReportScreen({super.key});

  @override
  State<AuditReportScreen> createState() => _AuditReportScreenState();
}

class _AuditReportScreenState extends State<AuditReportScreen> {
  // Defaults to the current year; user can pick an earlier one
  int _selectedYear = DateTime.now().year;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;

    // Build a list of selectable years: current year back to 2020
    final years = List.generate(
      DateTime.now().year - 2020 + 1,
      (i) => DateTime.now().year - i,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Year-End Financial Report')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'This generates a formal, audit-ready PDF covering your selected '
                'year — suitable for GRA review, bank loan applications, or your '
                'own records.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Select Report Year', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedYear,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: years
                  .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                  .toList(),
              onChanged: (val) => setState(() => _selectedYear = val ?? _selectedYear),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : () => _generatePdf(profile),
                icon: _isGenerating
                    ? const SizedBox(
                        height: 16, width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_isGenerating ? 'Generating...' : 'Generate PDF Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── _generatePdf: build and share the audit PDF ─────────────
  Future<void> _generatePdf(BusinessProfile? profile) async {
    setState(() => _isGenerating = true);

    try {
      // Step 1: Fetch all data for the selected year
      final db = DatabaseHelper.instance;
      final incomeRows   = await db.getIncomeForYear(_selectedYear);
      final expenseRows  = await db.getExpensesForYear(_selectedYear);
      final salesRows    = await db.getSalesForYear(_selectedYear);
      final turnover     = await db.getAnnualTurnover(_selectedYear);
      final cogs         = await db.getAnnualCogs(_selectedYear);

      final totalIncome   = incomeRows.fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
      final totalExpenses = expenseRows.fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
      final grossProfit   = totalIncome - cogs;
      final netProfit     = grossProfit - totalExpenses;
      final grossMargin   = totalIncome <= 0 ? 0.0 : (grossProfit / totalIncome) * 100;
      final netMargin     = totalIncome <= 0 ? 0.0 : (netProfit / totalIncome) * 100;
      final vatPercent    = (turnover / 750000 * 100).clamp(0, 999);

      // Step 2: Build the PDF document
      final pdf = pw.Document();

      // ── PAGE 1: Cover + Executive Summary ──────────────────
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('JavisAudit',
                  style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
              pw.Text('Year-End Financial Report — $_selectedYear',
                  style: const pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 4),
              pw.Text('Generated: ${AppFormat.displayDate(AppFormat.today())}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 12),

              // Business identity block
              pw.Text('Business Details', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _pdfRow('Business Name', profile?.businessName ?? '—'),
              _pdfRow('Owner', profile?.ownerName ?? '—'),
              _pdfRow('Business Type', profile?.businessType ?? '—'),
              _pdfRow('GRA TIN', profile?.graTin ?? 'Not provided'),
              _pdfRow('Location', profile?.location ?? '—'),
              pw.SizedBox(height: 20),

              // Executive summary
              pw.Text('Executive Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _pdfRow('Total Income', AppFormat.pdfCurrency(totalIncome)),
              _pdfRow('Cost of Goods Sold (COGS)', AppFormat.pdfCurrency(cogs)),
              _pdfRow('Gross Profit', '${AppFormat.pdfCurrency(grossProfit)}  (${grossMargin.toStringAsFixed(1)}% margin)'),
              _pdfRow('Total Expenses', AppFormat.pdfCurrency(totalExpenses)),
              _pdfRow(netProfit >= 0 ? 'Net Profit' : 'Net Loss',
                  '${AppFormat.pdfCurrency(netProfit)}  (${netMargin.toStringAsFixed(1)}% margin)'),
              _pdfRow('Cumulative Turnover', AppFormat.pdfCurrency(turnover)),
              _pdfRow('VAT Threshold Status',
                  '${vatPercent.toStringAsFixed(1)}% of GHS 750,000'
                  '${turnover >= 750000 ? " — EXCEEDED" : ""}'),
            ],
          ),
        ),
      );

      // ── PAGE 2: Monthly Breakdown Table ────────────────────
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            // Build monthly totals from raw rows
            final monthlyIncome = List.generate(12, (i) {
              final m = (i + 1).toString().padLeft(2, '0');
              return incomeRows
                  .where((r) => (r['date'] as String).substring(5, 7) == m)
                  .fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
            });
            final monthlyExpense = List.generate(12, (i) {
              final m = (i + 1).toString().padLeft(2, '0');
              return expenseRows
                  .where((r) => (r['date'] as String).substring(5, 7) == m)
                  .fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
            });

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Monthly Income & Expense Breakdown',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.green800),
                      children: [
                        _pdfCell('Month', isHeader: true),
                        _pdfCell('Income', isHeader: true),
                        _pdfCell('Expenses', isHeader: true),
                        _pdfCell('Net', isHeader: true),
                      ],
                    ),
                    ...List.generate(12, (i) {
                      final m = (i + 1).toString().padLeft(2, '0');
                      final net = monthlyIncome[i] - monthlyExpense[i];
                      return pw.TableRow(children: [
                        _pdfCell(AppFormat.monthName(m)),
                        _pdfCell(AppFormat.amount(monthlyIncome[i])),
                        _pdfCell(AppFormat.amount(monthlyExpense[i])),
                        _pdfCell(AppFormat.amount(net)),
                      ]);
                    }),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // ── PAGE 3: Income Detail ──────────────────────────────
      if (incomeRows.isNotEmpty) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (context) => [
              pw.Text('Income Detail — $_selectedYear',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.green800),
                    children: [
                      _pdfCell('Date', isHeader: true),
                      _pdfCell('Description', isHeader: true),
                      _pdfCell('Category', isHeader: true),
                      _pdfCell('Amount', isHeader: true),
                    ],
                  ),
                  ...incomeRows.map((r) => pw.TableRow(children: [
                        _pdfCell(AppFormat.displayDate(r['date'] as String)),
                        _pdfCell(r['description'] as String),
                        _pdfCell(r['category'] as String),
                        _pdfCell(AppFormat.amount((r['amount'] as num).toDouble())),
                      ])),
                ],
              ),
            ],
          ),
        );
      }

      // ── PAGE 4: Expense Detail ──────────────────────────────
      if (expenseRows.isNotEmpty) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (context) => [
              pw.Text('Expense Detail — $_selectedYear',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.red800),
                    children: [
                      _pdfCell('Date', isHeader: true),
                      _pdfCell('Description', isHeader: true),
                      _pdfCell('Category', isHeader: true),
                      _pdfCell('Amount', isHeader: true),
                    ],
                  ),
                  ...expenseRows.map((r) => pw.TableRow(children: [
                        _pdfCell(AppFormat.displayDate(r['date'] as String)),
                        _pdfCell(r['description'] as String),
                        _pdfCell(r['category'] as String),
                        _pdfCell(AppFormat.amount((r['amount'] as num).toDouble())),
                      ])),
                ],
              ),
            ],
          ),
        );
      }

      // ── PAGE 5: Disclaimer ──────────────────────────────────
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Disclaimer', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(
                'This report is generated from self-reported data entered by the '
                'business owner into the JavisAudit application. JavisAudit does not '
                'independently verify the accuracy of any figures presented. This '
                'document is intended to support record-keeping and compliance '
                'preparation and should be reviewed alongside original receipts and '
                'bank/mobile money statements before submission to the Ghana Revenue '
                'Authority or any financial institution.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      );

      // Step 3: Show an in-app preview of the report first — the
      // owner can review every page, then choose to print, save,
      // or share from right inside that preview screen.
      final bytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'JavisAudit_Financial_Report_$_selectedYear.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ── Small helper widgets for building PDF content ───────────
  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 160,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          ),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _pdfCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          color: isHeader ? PdfColors.white : PdfColors.black,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
