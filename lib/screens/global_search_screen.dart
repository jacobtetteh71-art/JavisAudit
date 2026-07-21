// ============================================================
// screens/global_search_screen.dart  –  Search Everything
// ============================================================
// One search box across Income, Expenses, and Sales — matched on
// description/category (and customer name, for Sales). Useful for
// "when did I last buy from that supplier" or "find that big sale".
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../utils/utils.dart';
import 'income_screen.dart';
import 'expense_screen.dart';
import 'sales_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    // Wait for a short pause in typing before hitting the database
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    final rows = await DatabaseHelper.instance.globalSearch(query);
    if (!mounted) return;
    setState(() {
      _results = rows;
      _isSearching = false;
      _hasSearched = true;
    });
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Income':
        return AppColors.income;
      case 'Expense':
        return AppColors.expense;
      default:
        return AppColors.gold;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Income':
        return Icons.arrow_downward;
      case 'Expense':
        return Icons.arrow_upward;
      default:
        return Icons.point_of_sale_outlined;
    }
  }

  // Opens the screen that owns this record type. The record list
  // there is filterable/scrollable, so this gets the owner straight
  // to the right place to find the exact entry.
  void _openRecord(String type) {
    Widget screen;
    switch (type) {
      case 'Income':
        screen = const IncomeScreen();
        break;
      case 'Expense':
        screen = const ExpenseScreen();
        break;
      default:
        screen = const SalesScreen();
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Search income, expenses, sales…',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : !_hasSearched
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Search across every income, expense, and sale record by '
                      'description, category, or customer name.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : _results.isEmpty
                  ? const Center(
                      child: Text('No matching records found.', style: TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _results.length,
                      itemBuilder: (_, index) {
                        final row = _results[index];
                        final type = row['record_type'] as String;
                        final amount = (row['amount'] as num).toDouble();
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _openRecord(type),
                          child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34, height: 34,
                                decoration: BoxDecoration(
                                  color: _typeColor(type).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(_typeIcon(type), size: 16, color: _typeColor(type)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(row['description'] as String? ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$type • ${AppFormat.displayDate(row['date'] as String)}'
                                      '${(row['category'] as String?)?.isNotEmpty == true ? " • ${row['category']}" : ""}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                AppFormat.currency(amount),
                                style: TextStyle(fontWeight: FontWeight.bold, color: _typeColor(type)),
                              ),
                            ],
                          ),
                          ),
                        );
                      },
                    ),
    );
  }
}
