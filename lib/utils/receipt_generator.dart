// ============================================================
// utils/receipt_generator.dart  –  Shareable Sale Receipt PDF
// ============================================================
// A short, single-page receipt for one sale — distinct from the
// multi-page Year-End Financial Report. Meant to be handed to (or
// WhatsApp'd to) a customer right after a sale, not filed for
// compliance purposes.
// ============================================================

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import 'utils.dart';

Future<void> shareSaleReceipt({
  required BusinessProfile? profile,
  required Sale sale,
}) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(profile?.businessName ?? 'JavisAudit',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            if (profile?.location != null && profile!.location!.isNotEmpty)
              pw.Text(profile.location!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text('SALES RECEIPT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 8),

            _row('Date', AppFormat.displayDate(sale.date)),
            if (sale.customerName != null && sale.customerName!.trim().isNotEmpty)
              _row('Customer', sale.customerName!),
            if (sale.id != null) _row('Receipt No.', 'JA-${sale.id.toString().padLeft(5, '0')}'),
            pw.SizedBox(height: 10),

            // ── Item table ────────────────────────────────
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
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _cell('Item', isHeader: true),
                    _cell('Qty', isHeader: true),
                    _cell('Unit Price', isHeader: true),
                    _cell('Total', isHeader: true),
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
            pw.SizedBox(height: 12),

            _row('Payment Method', sale.paymentMethod),
            _row('Payment Status', sale.paymentStatus),
            if (sale.paymentStatus != 'Paid') ...[
              _row('Amount Paid', AppFormat.pdfCurrency(sale.amountPaid)),
              _row('Balance Due', AppFormat.pdfCurrency(sale.balance)),
            ],
            if (sale.chequeNumber != null && sale.chequeNumber!.isNotEmpty)
              _row('Cheque No.', sale.chequeNumber!),

            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(width: 1, color: PdfColors.black)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text(AppFormat.pdfCurrency(sale.totalAmount),
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),

            pw.SizedBox(height: 20),
            pw.Text('Thank you for your business!',
                style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text('Generated via JavisAudit', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        );
      },
    ),
  );

  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: 'Receipt_${sale.id ?? DateTime.now().millisecondsSinceEpoch}.pdf',
  );
}

pw.Widget _row(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      children: [
        pw.SizedBox(width: 110, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

pw.Widget _cell(String text, {bool isHeader = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
    ),
  );
}
