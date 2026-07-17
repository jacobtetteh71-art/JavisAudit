// ============================================================
// providers/income_provider.dart  –  Income State Manager
// ============================================================
// ChangeNotifier is Flutter's built-in state management class.
// When we call notifyListeners(), every widget that is
// "listening" to this provider will automatically rebuild.
// ============================================================

import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class IncomeProvider extends ChangeNotifier {
  // The in-memory list of income records displayed in the UI
  List<Income> _incomes = [];
  bool _isLoading = false;

  // Getters — widgets read these to get the current state
  List<Income> get incomes   => _incomes;
  bool         get isLoading => _isLoading;

  // ── loadAll: fetch all income from SQLite ──────────────────
  // Called when the Income screen is first opened.
  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    final rows = await DatabaseHelper.instance.getAllIncome();
    // Convert each Map row into a typed Income object
    _incomes = rows.map((row) => Income.fromMap(row)).toList();

    _isLoading = false;
    notifyListeners();
  }

  // ── addIncome: validate, insert, and refresh ───────────────
  // Returns true on success, false if something went wrong.
  Future<bool> addIncome(Income income) async {
    try {
      // Insert into SQLite — toMap() strips the null id field
      await DatabaseHelper.instance.insertIncome(income.toMap());

      // Refresh the in-memory list so the UI shows the new entry
      await loadAll();
      return true;
    } catch (e) {
      debugPrint('Error inserting income: $e');
      return false;
    }
  }

  // ── deleteIncome: remove a record by its id ────────────────
  Future<bool> deleteIncome(int id) async {
    try {
      await DatabaseHelper.instance.deleteIncome(id);
      // Remove from in-memory list immediately (faster UI update)
      _incomes.removeWhere((i) => i.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting income: $e');
      return false;
    }
  }
}
