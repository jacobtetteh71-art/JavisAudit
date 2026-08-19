// ============================================================
// utils/expense_receipt_generator.dart  –  Shareable Expense Receipt
// ============================================================
// A short, single-page receipt generated whenever a payment is
// made towards an expense — either the full amount at the moment
// the expense is created as 'Paid', or one installment recorded
// later. Mirrors receipt_generator.dart's sale receipt exactly,
// so the two feel like one consistent "receipts" feature.
// ============================================================

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import 'utils.dart';
import 'document_generator.dart';

// If `payment` is given, the receipt is for THAT specific
// installment (amount/date/method come from the payment). If it's
// null, the receipt is for the expense's full amount, paid in one
// go at creation.
Future<void> shareExpenseReceipt({
  required BusinessProfile? profile,
  required Expense expense,
  ExpensePayment? payment,
}) async {
  final pdf = pw.Document();

  final receiptAmount = payment?.amount ?? expense.amount;
  final receiptDate = payment?.date ?? expense.date;
  final receiptMethod = payment?.paymentMethod ?? expense.paymentMethod;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      footer: (context) => buildFooter(profile, context),
      build: (context) {
        return [
          pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildLetterhead(profile, 'Payment Receipt'),

            _row('Date', AppFormat.displayDate(receiptDate)),
            if (expense.id != null) _row('Reference No.', 'JA-EXP-${expense.id.toString().padLeft(5, '0')}'),
            if (expense.receiptNo != null && expense.receiptNo!.isNotEmpty)
              _row('Original Invoice/Receipt No.', expense.receiptNo!),
            pw.SizedBox(height: 10),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _cell('Description', isHeader: true),
                    _cell('Category', isHeader: true),
                    _cell('Amount', isHeader: true),
                  ],
                ),
                pw.TableRow(children: [
                  _cell(expense.description),
                  _cell(expense.category),
                  _cell(AppFormat.pdfCurrency(receiptAmount)),
                ]),
              ],
            ),
            pw.SizedBox(height: 12),

            _row('Payment Method', receiptMethod),
            _row(
              payment != null ? 'This Installment' : 'Payment Status',
              payment != null ? AppFormat.pdfCurrency(payment.amount) : expense.paymentStatus,
            ),
            if (payment != null) ...[
              _row('Total Expense Amount', AppFormat.pdfCurrency(expense.amount)),
              _row('Balance Remaining', AppFormat.pdfCurrency(expense.balance)),
            ],
            if (expense.chequeNumber != null && expense.chequeNumber!.isNotEmpty)
              _row('Cheque No.', expense.chequeNumber!),

            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(width: 1, color: PdfColors.black)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('AMOUNT RECEIVED', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text(AppFormat.pdfCurrency(receiptAmount),
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),

            pw.SizedBox(height: 20),
            pw.Text(
              'This receipt confirms payment made by ${profile?.businessName ?? "this business"}.',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
            ),
          ],
          ),
        ];
      },
    ),
  );

  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: 'Payment_Receipt_${expense.id ?? DateTime.now().millisecondsSinceEpoch}.pdf',
  );
}

pw.Widget _row(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      children: [
        pw.SizedBox(width: 140, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
        pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
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
