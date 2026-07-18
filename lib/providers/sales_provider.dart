// ============================================================
// providers/sales_provider.dart  –  Sales State Manager
// ============================================================

import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class SalesProvider extends ChangeNotifier {
  List<Sale> _sales = [];
  bool _isLoading = false;

  List<Sale> get sales     => _sales;
  bool       get isLoading => _isLoading;

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    final rows = await DatabaseHelper.instance.getAllSales();
    _sales = rows.map((row) => Sale.fromMap(row)).toList();

    _isLoading = false;
    notifyListeners();
  }

  // ── addSale: insert sale and optionally auto-create income ─
  // If the sale's payment_status is 'Paid', we ALSO insert a
  // matching income entry so the VAT cumulative total is correct.
  Future<bool> addSale(Sale sale) async {
    try {
      int? autoIncomeId;

      // Only create an income entry for fully paid sales
      if (sale.paymentStatus == 'Paid') {
        // Build the auto-generated income entry
        final autoIncome = {
          'date':           sale.date,
          'amount':         sale.totalAmount,
          'description':    'Sale: ${sale.itemDescription}'
                            '${sale.customerName != null ? " (${sale.customerName})" : ""}',
          'category':       'Sales Revenue',
          'payment_method': sale.paymentMethod,
          'notes':          'Auto-created from Sales entry',
          'created_at':     DateTime.now().toIso8601String(),
        };
        // Insert the income entry and get its new id
        autoIncomeId = await DatabaseHelper.instance.insertIncome(autoIncome);
      }

      // A 'Paid' sale is fully paid from the moment it's recorded.
      // 'Pending'/'Partial Payment' keep whatever amountPaid was
      // entered on the Add Sale form (0 for Pending, a starting
      // deposit for Partial Payment).
      final resolvedAmountPaid = sale.paymentStatus == 'Paid' ? sale.totalAmount : sale.amountPaid;

      // Now insert the sale record, linking it to the income entry
      final saleMap = sale.toMap();
      saleMap['income_id'] = autoIncomeId; // will be null if not Paid
      saleMap['amount_paid'] = resolvedAmountPaid;
      await DatabaseHelper.instance.insertSale(saleMap);

      await loadAll();
      return true;
    } catch (e) {
      debugPrint('Error inserting sale: $e');
      return false;
    }
  }

  Future<bool> deleteSale(int id) async {
    try {
      await DatabaseHelper.instance.deleteSale(id);
      _sales.removeWhere((s) => s.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting sale: $e');
      return false;
    }
  }

  // ── Payment history for one sale (oldest first) ────────────
  Future<List<SalePayment>> getPayments(int saleId) async {
    final rows = await DatabaseHelper.instance.getPaymentsForSale(saleId);
    return rows.map((row) => SalePayment.fromMap(row)).toList();
  }

  // ── recordPayment: the "finish paying" / installment flow ──
  // Adds one payment towards a Pending or Partial Payment sale.
  // If the new total paid reaches the full amount, the sale is
  // automatically flipped to 'Paid' AND a matching income entry
  // is created — exactly like a sale that was marked Paid from
  // the start. This keeps the VAT turnover calculation accurate
  // regardless of whether a sale was paid in full immediately or
  // across several installments.
  Future<bool> recordPayment({
    required int saleId,
    required double amount,
    required String date,
    required String paymentMethod,
  }) async {
    try {
      final saleIndex = _sales.indexWhere((s) => s.id == saleId);
      if (saleIndex == -1) return false;
      final sale = _sales[saleIndex];

      // Never let the recorded total exceed the sale's total amount
      final newAmountPaid =
          (sale.amountPaid + amount) > sale.totalAmount ? sale.totalAmount : sale.amountPaid + amount;

      final bool nowFullyPaid = newAmountPaid >= sale.totalAmount;
      final String newStatus = nowFullyPaid
          ? 'Paid'
          : (newAmountPaid > 0 ? 'Partial Payment' : 'Pending');

      int? incomeId = sale.incomeId;

      // If this payment completes the sale AND no income entry
      // exists yet for it, create one now — same auto-income
      // behaviour as a sale that starts out as 'Paid'.
      if (nowFullyPaid && incomeId == null) {
        final autoIncome = {
          'date':           date,
          'amount':         sale.totalAmount,
          'description':    'Sale: ${sale.itemDescription}'
                            '${sale.customerName != null ? " (${sale.customerName})" : ""}',
          'category':       'Sales Revenue',
          'payment_method': paymentMethod,
          'notes':          'Auto-created when sale was fully paid off',
          'created_at':     DateTime.now().toIso8601String(),
        };
        incomeId = await DatabaseHelper.instance.insertIncome(autoIncome);
      }

      final payment = SalePayment(
        saleId: saleId,
        amount: amount,
        paymentMethod: paymentMethod,
        date: date,
        createdAt: DateTime.now().toIso8601String(),
      ).toMap();

      final updatedSale = {
        'amount_paid':    newAmountPaid,
        'payment_status': newStatus,
        'income_id':      incomeId,
      };

      await DatabaseHelper.instance.recordSalePayment(
        saleId: saleId,
        updatedSale: updatedSale,
        payment: payment,
      );

      await loadAll();
      return true;
    } catch (e) {
      debugPrint('Error recording payment: $e');
      return false;
    }
  }
}
