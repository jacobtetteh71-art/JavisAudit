// ============================================================
// providers/invoice_provider.dart  –  Invoice State Manager
// ============================================================
// Handles both Invoices and Pro-forma Invoices (see models.dart's
// Invoice class for what distinguishes them). Two things this
// provider does that are worth calling out because they touch OTHER
// parts of the ledger:
//
//   • markAsPaid() creates a real Sale (and, via that, an Income
//     entry) for each line item — the same auto-income behaviour
//     Sales already has. This is the ONLY point at which an Invoice
//     affects the rest of the books; simply creating or sending an
//     invoice never does.
//
//   • convertToInvoice() turns a Pro-forma into a brand-new real
//     Invoice (new row, new auto-numbered invoice_number) and marks
//     the original Pro-forma as 'Converted' — it does NOT touch
//     Sales/Income itself; the new Invoice then follows the normal
//     Invoice lifecycle (including its own eventual markAsPaid).
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class InvoiceProvider extends ChangeNotifier {
  List<Invoice> _invoices = [];
  bool _isLoading = false;

  List<Invoice> get invoices  => _invoices;
  bool get isLoading          => _isLoading;

  List<Invoice> get realInvoices => _invoices.where((i) => !i.isProforma).toList();
  List<Invoice> get proformaInvoices => _invoices.where((i) => i.isProforma).toList();

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    final rows = await DatabaseHelper.instance.getAllInvoices();
    _invoices = rows.map((row) => Invoice.fromMap(row)).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<List<InvoiceItem>> getItems(int invoiceId) async {
    final rows = await DatabaseHelper.instance.getInvoiceItems(invoiceId);
    return rows.map((row) => InvoiceItem.fromMap(row)).toList();
  }

  // ── addInvoice: create a new Invoice or Pro-forma ────────────
  // documentType and every other field come from the caller;
  // this just fills in the auto-generated invoice_number and
  // saves the header + line items together.
  Future<bool> addInvoice(Invoice invoice, List<InvoiceItem> items) async {
    try {
      final number = await DatabaseHelper.instance.generateNextInvoiceNumber(invoice.documentType);
      final total = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
      final withNumber = Invoice(
        documentType: invoice.documentType,
        invoiceNumber: number,
        date: invoice.date,
        dueDate: invoice.dueDate,
        customerName: invoice.customerName,
        customerPhone: invoice.customerPhone,
        customerAddress: invoice.customerAddress,
        notes: invoice.notes,
        status: invoice.status,
        totalAmount: total,
        createdAt: invoice.createdAt,
      );

      await DatabaseHelper.instance.insertInvoiceWithItems(
        withNumber.toMap(),
        items.map((i) => i.toMap()).toList(),
      );

      await loadAll();
      return true;
    } catch (e) {
      debugPrint('Error creating invoice: $e');
      return false;
    }
  }

  Future<bool> updateStatus(int id, String status) async {
    try {
      await DatabaseHelper.instance.updateInvoice(id, {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await loadAll();
      return true;
    } catch (e) {
      debugPrint('Error updating invoice status: $e');
      return false;
    }
  }

  Future<bool> deleteInvoice(int id) async {
    try {
      await DatabaseHelper.instance.deleteInvoice(id);
      _invoices.removeWhere((i) => i.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting invoice: $e');
      return false;
    }
  }

  // ── markAsPaid: the "money actually arrived" step ────────────
  // Creates one Sale per line item (grouped via saleGroupId when
  // there's more than one — same convention the Sales screen's own
  // multi-item entry uses), each immediately 'Paid', which — via
  // the same auto-income behaviour Sales already has — also creates
  // a matching Income entry per item. The invoice itself is then
  // flipped to 'Paid' and records which saleGroupId came from it,
  // so its detail view can link straight through to the resulting
  // Sales.
  Future<bool> markAsPaid({
    required int invoiceId,
    required String paymentMethod,
    required String paymentDate,
  }) async {
    try {
      final invoice = _invoices.firstWhere((i) => i.id == invoiceId);
      final items = await getItems(invoiceId);
      if (items.isEmpty) return false;

      final saleGroupId = items.length > 1 ? const Uuid().v4() : null;

      for (final item in items) {
        final autoIncome = {
          'date': paymentDate,
          'amount': item.lineTotal,
          'description': 'Invoice ${invoice.invoiceNumber}: ${item.description} (${invoice.customerName})',
          'category': 'Sales Revenue',
          'payment_method': paymentMethod,
          'notes': 'Auto-created from Invoice ${invoice.invoiceNumber}',
          'created_at': DateTime.now().toIso8601String(),
        };
        final incomeId = await DatabaseHelper.instance.insertIncome(autoIncome);

        final saleMap = Sale(
          date: paymentDate,
          customerName: invoice.customerName,
          itemDescription: item.description,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          totalAmount: item.lineTotal,
          paymentMethod: paymentMethod,
          paymentStatus: 'Paid',
          amountPaid: item.lineTotal,
          notes: 'From Invoice ${invoice.invoiceNumber}',
          saleGroupId: saleGroupId,
          createdAt: DateTime.now().toIso8601String(),
        ).toMap();
        saleMap['income_id'] = incomeId;
        await DatabaseHelper.instance.insertSale(saleMap);
      }

      await DatabaseHelper.instance.updateInvoice(invoiceId, {
        'status': 'Paid',
        'sale_group_id': saleGroupId,
        'updated_at': DateTime.now().toIso8601String(),
      });

      await loadAll();
      return true;
    } catch (e) {
      debugPrint('Error marking invoice as paid: $e');
      return false;
    }
  }

  // ── convertToInvoice: turn an accepted Pro-forma into a real one ──
  // Duplicates the Pro-forma's header (with a fresh Invoice number
  // and today's date) and every line item into a brand-new Invoice
  // row, then marks the original Pro-forma 'Converted' and links it
  // to the new Invoice's id. Returns the new Invoice's id on
  // success, so the caller can navigate straight to it.
  Future<int?> convertToInvoice(int proformaId) async {
    try {
      final proforma = _invoices.firstWhere((i) => i.id == proformaId);
      final items = await getItems(proformaId);

      final number = await DatabaseHelper.instance.generateNextInvoiceNumber('Invoice');
      final newInvoice = Invoice(
        documentType: 'Invoice',
        invoiceNumber: number,
        date: DateTime.now().toIso8601String().substring(0, 10),
        customerName: proforma.customerName,
        customerPhone: proforma.customerPhone,
        customerAddress: proforma.customerAddress,
        notes: proforma.notes,
        status: 'Draft',
        totalAmount: proforma.totalAmount,
        createdAt: DateTime.now().toIso8601String(),
      );

      final newId = await DatabaseHelper.instance.insertInvoiceWithItems(
        newInvoice.toMap(),
        items.map((i) => i.toMap()).toList(),
      );

      await DatabaseHelper.instance.updateInvoice(proformaId, {
        'status': 'Converted',
        'converted_to_invoice_id': newId,
        'updated_at': DateTime.now().toIso8601String(),
      });

      await loadAll();
      return newId;
    } catch (e) {
      debugPrint('Error converting pro-forma to invoice: $e');
      return null;
    }
  }
}
