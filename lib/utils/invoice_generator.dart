// ============================================================
// utils/invoice_generator.dart  –  Shareable Invoice / Pro-forma PDF
// ============================================================
// Reuses buildLetterhead/buildFooter (business header/footer, same
// as every other document) and buildPaymentDetailsBlock — the
// Mobile Money/bank info from the business profile, shown here
// because both an Invoice and a Pro-forma request a payment that
// hasn't happened yet, unlike a Sales/Expense receipt.
// ============================================================

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import 'utils.dart';
import 'document_generator.dart';

Future<void> shareInvoicePdf(
  Invoice invoice,
  List<InvoiceItem> items, {
  required BusinessProfile? profile,
}) async {
  final pdf = pw.Document();
  final isProforma = invoice.isProforma;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (context) => buildFooter(profile, context),
      build: (context) {
        return [
          buildLetterhead(profile, isProforma ? 'Pro-forma Invoice' : 'Invoice'),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Bill To', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text(invoice.customerName),
                  if (invoice.customerPhone != null) pw.Text(invoice.customerPhone!),
                  if (invoice.customerAddress != null) pw.Text(invoice.customerAddress!),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('${isProforma ? "Pro-forma" : "Invoice"} #: ${invoice.invoiceNumber}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: ${AppFormat.displayDate(invoice.date)}'),
                  if (invoice.dueDate != null) pw.Text('Due: ${AppFormat.displayDate(invoice.dueDate!)}'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),

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
                  _cell('Description', isHeader: true),
                  _cell('Qty', isHeader: true),
                  _cell('Unit Price', isHeader: true),
                  _cell('Total', isHeader: true),
                ],
              ),
              for (final item in items)
                pw.TableRow(children: [
                  _cell(item.description),
                  _cell('${item.quantity}'),
                  _cell(AppFormat.pdfCurrency(item.unitPrice)),
                  _cell(AppFormat.pdfCurrency(item.lineTotal)),
                ]),
            ],
          ),
          pw.SizedBox(height: 12),

          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: 1, color: PdfColors.black)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.Text(AppFormat.pdfCurrency(invoice.totalAmount),
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),

          if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('Notes', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text(invoice.notes!, style: const pw.TextStyle(fontSize: 10)),
          ],

          if (isProforma) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'This is a Pro-forma Invoice — an estimate only, not a demand for payment. '
              'Prices and availability are subject to confirmation.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
            ),
          ],

          buildPaymentDetailsBlock(profile),
        ];
      },
    ),
  );

  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: '${invoice.invoiceNumber}.pdf',
  );
}

pw.Widget _cell(String text, {bool isHeader = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: isHeader ? PdfColors.white : PdfColors.black,
      ),
    ),
  );
}
