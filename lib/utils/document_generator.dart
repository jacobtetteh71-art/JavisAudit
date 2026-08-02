// ============================================================
// utils/document_generator.dart  –  Uniform Printable Documents
// ============================================================
// Shared PDF layouts so that anything the owner prints out —
// a stock summary, a bid/tender document package cover sheet —
// looks consistent, with the same letterhead, fonts, and spacing.
// ============================================================

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import 'utils.dart';

// A consistent header block used at the top of every uniform
// document — business name, location, and a document title.
pw.Widget buildLetterhead(BusinessProfile? profile, String documentTitle) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(profile?.businessName ?? 'JavisAudit',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      if (profile?.location != null && profile!.location!.isNotEmpty)
        pw.Text(profile.location!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      if (profile?.ownerName != null && profile!.ownerName.isNotEmpty)
        pw.Text('Owner: ${profile.ownerName}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      pw.SizedBox(height: 10),
      pw.Text(documentTitle.toUpperCase(),
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
      pw.Text('Generated ${AppFormat.displayDate(AppFormat.today())}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      pw.Divider(thickness: 1.2, color: PdfColors.grey800),
      pw.SizedBox(height: 10),
    ],
  );
}

// ── Stock Summary ─────────────────────────────────────────
Future<void> printStockSummary(List<InventoryItem> items) async {
  final pdf = pw.Document();
  final totalStockValue = items.fold<double>(0, (s, i) => s + i.stockValue);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => context.pageNumber == 1
          ? buildLetterhead(null, 'Stock Summary')
          : pw.SizedBox(),
      build: (context) => [
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1.3),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(1.5),
            4: pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _cell('Item', isHeader: true),
                _cell('In Stock', isHeader: true),
                _cell('Cost/Unit', isHeader: true),
                _cell('Sells For', isHeader: true),
                _cell('Stock Value', isHeader: true),
              ],
            ),
            ...items.map((item) => pw.TableRow(children: [
                  _cell(item.name),
                  _cell('${item.stockQuantity}${item.unit != null ? " ${item.unit}" : ""}'),
                  _cell(AppFormat.pdfCurrency(item.costPrice)),
                  _cell(AppFormat.pdfCurrency(item.sellingPrice)),
                  _cell(AppFormat.pdfCurrency(item.stockValue)),
                ])),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(width: 1, color: PdfColors.black)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TOTAL STOCK VALUE (at cost)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(AppFormat.pdfCurrency(totalStockValue), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      ],
    ),
  );

  await Printing.sharePdf(bytes: await pdf.save(), filename: 'Stock_Summary_${AppFormat.today()}.pdf');
}

pw.Widget _cell(String text, {bool isHeader = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal)),
  );
}
