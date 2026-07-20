// ============================================================
// utils/receipt_generator.dart  –  Per-Sale Receipt PDF
// ============================================================
// Generates a single-page receipt for ONE sale — something the
// owner can hand or share (WhatsApp/SMS/email) to the customer
// right after the transaction, as proof of purchase/payment.
// This is distinct from the year-end Audit Report PDF, which is
// a formal report for the owner's own records/GRA/bank use.
// ============================================================

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import 'utils.dart';

Future<void> shareSaleReceipt({
  required Sale sale,
  required List<SalePayment> payments,
  required BusinessProfile? profile,
}) async {
  final pdf = pw.Document();

  // Load the business logo if a profile picture has been set —
  // falls back gracefully to just the business name if not.
  pw.ImageProvider? logoImage;
  if (profile?.profileImagePath != null && File(profile!.profileImagePath!).existsSync()) {
    logoImage = pw.MemoryImage(File(profile.profileImagePath!).readAsBytesSync());
  }

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5, // Receipts are naturally smaller than full A4 reports
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Header: business identity ─────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(profile?.businessName ?? 'JavisAudit',
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  if (profile?.phone != null) pw.Text(profile!.phone!, style: const pw.TextStyle(fontSize: 9)),
                  if (profile?.location != null)
                    pw.Text(profile!.location!, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              if (logoImage != null) pw.Image(logoImage, width: 44, height: 44),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1.2),
          pw.Center(
            child: pw.Text('SALES RECEIPT',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text('Receipt #${sale.id ?? '-'}  •  ${AppFormat.displayDate(sale.date)}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ),
          pw.SizedBox(height: 16),

          if (sale.customerName != null && sale.customerName!.isNotEmpty) ...[
            pw.Text('Customer', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.Text(sale.customerName!, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
          ],

          // ── Item table ─────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Item', bold: true),
                  _cell('Qty', bold: true),
                  _cell('Unit Price', bold: true),
                  _cell('Total', bold: true),
                ],
              ),
              pw.TableRow(children: [
                _cell(sale.itemDescription),
                _cell('${sale.quantity}'),
                _cell(AppFormat.pdfCurrency(sale.unitPrice)),
                _cell(AppFormat.pdfCurrency(sale.totalAmount)),
              ]),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── Amount summary ─────────────────────────────────
          _summaryRow('Total Amount', AppFormat.pdfCurrency(sale.totalAmount), bold: true),
          _summaryRow('Amount Paid', AppFormat.pdfCurrency(sale.amountPaid)),
          if (sale.paymentStatus != 'Paid')
            _summaryRow('Balance Due', AppFormat.pdfCurrency(sale.balance), color: PdfColors.red700),
          pw.SizedBox(height: 6),
          _summaryRow('Payment Method', sale.paymentMethod),
          _summaryRow('Status', sale.paymentStatus,
              color: sale.paymentStatus == 'Paid' ? PdfColors.green700 : PdfColors.orange700),

          // ── Payment history, if any installments were made ──
          if (payments.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('Payment History', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            ...payments.map((p) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${AppFormat.displayDate(p.date)} — ${p.paymentMethod}',
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(AppFormat.pdfCurrency(p.amount), style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                )),
          ],

          pw.SizedBox(height: 24),
          pw.Divider(thickness: 0.5),
          pw.Center(
            child: pw.Text('Thank you for your business!',
                style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
          ),
        ],
      ),
    ),
  );

  final safeCustomer = (sale.customerName ?? 'customer').replaceAll(RegExp(r'[^\w]+'), '_');
  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: 'Receipt_${safeCustomer}_${sale.date}.pdf',
  );
}

pw.Widget _cell(String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : null)),
  );
}

pw.Widget _summaryRow(String label, String value, {bool bold = false, PdfColor? color}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: bold ? 12 : 10,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ],
    ),
  );
}
