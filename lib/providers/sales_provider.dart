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

      // Only create an income entry for paid sales
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

      // Now insert the sale record, linking it to the income entry
      final saleMap = sale.toMap();
      saleMap['income_id'] = autoIncomeId; // will be null if not Paid
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
}
