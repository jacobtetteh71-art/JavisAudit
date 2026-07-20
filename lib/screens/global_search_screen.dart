// ============================================================
// screens/global_search_screen.dart  –  Search All Records
// ============================================================
// Searches across Income, Expense, and Sales records at once by
// description/category/customer/item name — much faster than
// hunting through three separate tabs and their date filters.
// ============================================================

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import 'income_screen.dart';
import 'expense_screen.dart';
import 'sales_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

// A single unified row used to render mixed result types together
class _SearchResult {
  final String type; // 'Income' | 'Expense' | 'Sale'
  final String title;
  final String subtitle;
  final double amount;
  final Color color;
  final VoidCallback onTap;

  _SearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
    required this.onTap,
  });
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _searchCtrl = TextEditingController();
  bool _isLoading = true;
  List<Income> _allIncome = [];
  List<Expense> _allExpenses = [];
  List<Sale> _allSales = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final incomeRows = await DatabaseHelper.instance.getAllIncome();
    final expenseRows = await DatabaseHelper.instance.getAllExpenses();
    final salesRows = await DatabaseHelper.instance.getAllSales();
    if (!mounted) return;
    setState(() {
      _allIncome = incomeRows.map((r) => Income.fromMap(r)).toList();
      _allExpenses = expenseRows.map((r) => Expense.fromMap(r)).toList();
      _allSales = salesRows.map((r) => Sale.fromMap(r)).toList();
      _isLoading = false;
    });
  }

  List<_SearchResult> get _results {
    if (_query.isEmpty) return [];

    final results = <_SearchResult>[];

    for (final income in _allIncome) {
      if (income.description.toLowerCase().contains(_query) ||
          income.category.toLowerCase().contains(_query)) {
        results.add(_SearchResult(
          type: 'Income',
          title: income.description,
          subtitle: '${income.category} • ${AppFormat.displayDate(income.date)}',
          amount: income.amount,
          color: AppColors.income,
          onTap: () => showIncomeDetailSheet(context, income),
        ));
      }
    }

    for (final expense in _allExpenses) {
      if (expense.description.toLowerCase().contains(_query) ||
          expense.category.toLowerCase().contains(_query)) {
        results.add(_SearchResult(
          type: 'Expense',
          title: expense.description,
          subtitle: '${expense.category} • ${AppFormat.displayDate(expense.date)}',
          amount: expense.amount,
          color: AppColors.expense,
          onTap: () => showExpenseDetailSheet(context, expense),
        ));
      }
    }

    for (final sale in _allSales) {
      final customer = sale.customerName ?? '';
      if (sale.itemDescription.toLowerCase().contains(_query) ||
          customer.toLowerCase().contains(_query)) {
        results.add(_SearchResult(
          type: 'Sale',
          title: sale.itemDescription,
          subtitle: '${customer.isNotEmpty ? "$customer • " : ""}${AppFormat.displayDate(sale.date)}',
          amount: sale.totalAmount,
          color: AppColors.gold,
          onTap: () => showSaleDetailSheet(context, sale),
        ));
      }
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search income, expenses, sales...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchCtrl.clear()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _query.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Type to search across all your Income, Expense, and Sales records at once.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : results.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No matching records found.', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final r = results[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: r.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(r.type,
                                  style: TextStyle(fontSize: 10, color: r.color, fontWeight: FontWeight.w700)),
                            ),
                            title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text(r.subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            trailing: Text(AppFormat.currency(r.amount),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: r.onTap,
                          ),
                        );
                      },
                    ),
    );
  }
}
