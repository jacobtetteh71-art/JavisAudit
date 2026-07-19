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

  // ── addExpense: resolves the starting amount_paid ───────────
  // A 'Paid' expense is fully settled the moment it's recorded.
  // 'Pending'/'Partial Payment' keep whatever amountPaid was
  // entered on the Add Expense form (0 for Pending, a starting
  // part-payment for Partial Payment).
  Future<bool> addExpense(Expense expense) async {
    try {
      final resolvedAmountPaid =
          expense.paymentStatus == 'Paid' ? expense.amount : expense.amountPaid;

      final map = expense.toMap();
      map['amount_paid'] = resolvedAmountPaid;

      await DatabaseHelper.instance.insertExpense(map);
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

  // ── Payment history for one expense (oldest first) ─────────
  Future<List<ExpensePayment>> getPayments(int expenseId) async {
    final rows = await DatabaseHelper.instance.getPaymentsForExpense(expenseId);
    return rows.map((row) => ExpensePayment.fromMap(row)).toList();
  }

  // ── recordPayment: log one installment towards an expense ──
  // Adds one payment towards a Pending or Partial Payment expense.
  // If the new total paid reaches the full amount, the expense is
  // automatically flipped to 'Paid'.
  Future<bool> recordPayment({
    required int expenseId,
    required double amount,
    required String date,
    required String paymentMethod,
  }) async {
    try {
      final index = _expenses.indexWhere((e) => e.id == expenseId);
      if (index == -1) return false;
      final expense = _expenses[index];

      // Never let the recorded total exceed the expense amount
      final newAmountPaid =
          (expense.amountPaid + amount) > expense.amount ? expense.amount : expense.amountPaid + amount;

      final bool nowFullyPaid = newAmountPaid >= expense.amount;
      final String newStatus = nowFullyPaid
          ? 'Paid'
          : (newAmountPaid > 0 ? 'Partial Payment' : 'Pending');

      final payment = ExpensePayment(
        expenseId: expenseId,
        amount: amount,
        paymentMethod: paymentMethod,
        date: date,
        createdAt: DateTime.now().toIso8601String(),
      ).toMap();

      final updatedExpense = {
        'amount_paid':    newAmountPaid,
        'payment_status': newStatus,
      };

      await DatabaseHelper.instance.recordExpensePayment(
        expenseId: expenseId,
        updatedExpense: updatedExpense,
        payment: payment,
      );

      await loadAll();
      return true;
    } catch (e) {
      debugPrint('Error recording expense payment: $e');
      return false;
    }
  }
}
