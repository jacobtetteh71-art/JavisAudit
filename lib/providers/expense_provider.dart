// ============================================================
// providers/expense_provider.dart  –  Expense State Manager
// ============================================================

import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class ExpenseProvider extends ChangeNotifier {
  List<Expense> _expenses = [];
  bool _isLoading = false;

  List<Expense> get expenses  => _expenses;
  bool          get isLoading => _isLoading;

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    final rows = await DatabaseHelper.instance.getAllExpenses();
    _expenses = rows.map((row) => Expense.fromMap(row)).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addExpense(Expense expense) async {
    try {
      await DatabaseHelper.instance.insertExpense(expense.toMap());
      await loadAll();
      return true;
    } catch (e) {
      debugPrint('Error inserting expense: $e');
      return false;
    }
  }

  Future<bool> deleteExpense(int id) async {
    try {
      await DatabaseHelper.instance.deleteExpense(id);
      _expenses.removeWhere((e) => e.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      return false;
    }
  }
}
