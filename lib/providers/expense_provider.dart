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

  // ══════════════════════════════════════════════════════════
  // RECURRING EXPENSE TEMPLATES
  // ══════════════════════════════════════════════════════════

  List<ExpenseTemplate> _templates = [];
  List<ExpenseTemplate> get templates => _templates;

  Future<void> loadTemplates() async {
    final rows = await DatabaseHelper.instance.getAllExpenseTemplates();
    _templates = rows.map((row) => ExpenseTemplate.fromMap(row)).toList();
    notifyListeners();
  }

  Future<bool> addTemplate(ExpenseTemplate template) async {
    try {
      await DatabaseHelper.instance.insertExpenseTemplate(template.toMap());
      await loadTemplates();
      return true;
    } catch (e) {
      debugPrint('Error saving expense template: $e');
      return false;
    }
  }

  Future<bool> deleteTemplate(int id) async {
    try {
      await DatabaseHelper.instance.deleteExpenseTemplate(id);
      _templates.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting expense template: $e');
      return false;
    }
  }

  // ── logTemplate: the "one tap to re-log this month's rent" action ─
  // Creates a brand-new Expense entry dated TODAY from the template's
  // saved details. Always logged as fully 'Paid' — if the owner needs
  // to log it as Pending/Partial instead, they can still do that
  // manually from the regular Add Expense form.
  Future<bool> logTemplate(ExpenseTemplate template) async {
    final expense = Expense(
      date: DateTime.now().toIso8601String().split('T').first,
      amount: template.amount,
      description: template.description,
      category: template.category,
      paymentMethod: template.paymentMethod,
      paymentStatus: 'Paid',
      notes: template.notes,
      createdAt: DateTime.now().toIso8601String(),
    );
    return await addExpense(expense);
  }
}
