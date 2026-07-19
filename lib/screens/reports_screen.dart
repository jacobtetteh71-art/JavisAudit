// ============================================================
// screens/reports_screen.dart  –  Step 8: Financial Reports
// ============================================================
// Four tabs: Weekly, Monthly, Profit & Loss, By Category.
// Demonstrates using a TabController to switch between report
// views, each running its own SQLite aggregation query.
// ============================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../database/database_helper.dart';
import '../utils/utils.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

// "with SingleTickerProviderStateMixin" is required for TabController's animation
class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 4 tabs: Weekly, Monthly, P&L, By Category
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Financial Reports'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          // FIX: without these, unselected tab labels default to a
          // low-contrast color that's nearly invisible against the
          // dark green header — explicitly set both to white so
          // every tab is clearly readable, selected or not.
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
            Tab(text: 'Profit & Loss'),
            Tab(text: 'By Category'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _WeeklyReport(),
          _MonthlyReport(),
          _ProfitLossReport(),
          _CategoryReport(),
        ],
      ),
    );
  }
}

// ============================================================
// _WeeklyReport  –  Last 7 days income vs expense
// ============================================================
class _WeeklyReport extends StatefulWidget {
  const _WeeklyReport();
  @override
  State<_WeeklyReport> createState() => _WeeklyReportState();
}

class _WeeklyReportState extends State<_WeeklyReport> {
  double _income = 0;
  double _expenses = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final startStr = AppFormat.dateToString(weekAgo);
    final endStr = AppFormat.dateToString(now);

    // Query both tables for the last 7 days
    final incomeRows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount),0) as t FROM income WHERE date BETWEEN ? AND ?",
      [startStr, endStr],
    );
    final expenseRows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount),0) as t FROM expenses WHERE date BETWEEN ? AND ?",
      [startStr, endStr],
    );

    if (!mounted) return;
    setState(() {
      _income = (incomeRows.first['t'] as num).toDouble();
      _expenses = (expenseRows.first['t'] as num).toDouble();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final profit = _income - _expenses;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Last 7 Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statBox('Income', _income, AppColors.income)),
            const SizedBox(width: 10),
            Expanded(child: _statBox('Expenses', _expenses, AppColors.expense)),
          ],
        ),
        const SizedBox(height: 10),
        _statBox('Net Profit', profit, profit >= 0 ? AppColors.income : AppColors.expense, fullWidth: true),
      ],
    );
  }

  Widget _statBox(String label, double value, Color color, {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(AppFormat.currency(value),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// ============================================================
// _MonthlyReport  –  Month-by-month P&L table for current year
// ============================================================
class _MonthlyReport extends StatefulWidget {
  const _MonthlyReport();
  @override
  State<_MonthlyReport> createState() => _MonthlyReportState();
}

class _MonthlyReportState extends State<_MonthlyReport> {
  List<Map<String, dynamic>> _incomeData = [];
  List<Map<String, dynamic>> _expenseData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final year = DateTime.now().year;
    final results = await Future.wait([
      DatabaseHelper.instance.getMonthlyIncomeBreakdown(year),
      DatabaseHelper.instance.getMonthlyExpenseBreakdown(year),
    ]);
    if (!mounted) return;
    setState(() {
      _incomeData = results[0];
      _expenseData = results[1];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final incomeMap = {for (var r in _incomeData) r['month'] as String: (r['total'] as num).toDouble()};
    final expenseMap = {for (var r in _expenseData) r['month'] as String: (r['total'] as num).toDouble()};

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 12,
      itemBuilder: (_, i) {
        final monthKey = (i + 1).toString().padLeft(2, '0');
        final income = incomeMap[monthKey] ?? 0;
        final expense = expenseMap[monthKey] ?? 0;
        final net = income - expense;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(AppFormat.monthName(monthKey),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Expanded(
                child: Text('In: ${AppFormat.amount(income)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.income)),
              ),
              Expanded(
                child: Text('Out: ${AppFormat.amount(expense)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.expense)),
              ),
              Text(
                AppFormat.amount(net),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: net >= 0 ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// _ProfitLossReport  –  Full year P&L statement
// ============================================================
class _ProfitLossReport extends StatefulWidget {
  const _ProfitLossReport();
  @override
  State<_ProfitLossReport> createState() => _ProfitLossReportState();
}

class _ProfitLossReportState extends State<_ProfitLossReport> {
  double _totalIncome = 0;
  double _totalExpenses = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final year = DateTime.now().year;
    _totalIncome = await DatabaseHelper.instance.getAnnualTurnover(year);

    final db = await DatabaseHelper.instance.database;
    final expRows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount),0) as t FROM expenses WHERE strftime('%Y', date) = ?",
      [year.toString()],
    );
    _totalExpenses = (expRows.first['t'] as num).toDouble();

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final net = _totalIncome - _totalExpenses;
    final isProfit = net >= 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Profit & Loss Statement — ${DateTime.now().year}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _plRow('Gross Income', _totalIncome, AppColors.income),
              const Divider(height: 24),
              _plRow('Total Expenses', -_totalExpenses, AppColors.expense),
              const Divider(height: 24),
              _plRow(
                isProfit ? 'Net Profit' : 'Net Loss',
                net,
                isProfit ? AppColors.income : AppColors.expense,
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _plRow(String label, double value, Color color, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(
          AppFormat.currency(value),
          style: TextStyle(
              fontSize: bold ? 16 : 13, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

// ============================================================
// _CategoryReport  –  Expense breakdown by category (pie chart)
// ============================================================
class _CategoryReport extends StatefulWidget {
  const _CategoryReport();
  @override
  State<_CategoryReport> createState() => _CategoryReportState();
}

class _CategoryReportState extends State<_CategoryReport> {
  List<Map<String, dynamic>> _categoryData = [];
  bool _loading = true;

  // A palette to colour each pie slice differently
  final List<Color> _palette = const [
    AppColors.primary, AppColors.gold, AppColors.expense, AppColors.info,
    Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF14B8A6), Color(0xFFF97316),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final year = DateTime.now().year;
    final data = await DatabaseHelper.instance.getExpensesByCategory(year);
    if (!mounted) return;
    setState(() {
      _categoryData = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_categoryData.isEmpty) {
      return const Center(
        child: Text('No expense data yet to show by category.',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final total = _categoryData.fold<double>(
        0, (sum, row) => sum + (row['total'] as num).toDouble());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Expenses by Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 16),

        // ── Pie chart ──────────────────────────────────────
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: List.generate(_categoryData.length, (i) {
                final row = _categoryData[i];
                final value = (row['total'] as num).toDouble();
                final percent = (value / total * 100);
                return PieChartSectionData(
                  value: value,
                  color: _palette[i % _palette.length],
                  title: '${percent.toStringAsFixed(0)}%',
                  radius: 60,
                  titleStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Legend list ────────────────────────────────────
        ...List.generate(_categoryData.length, (i) {
          final row = _categoryData[i];
          final value = (row['total'] as num).toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                      color: _palette[i % _palette.length], shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(row['category'] as String, style: const TextStyle(fontSize: 13))),
                Text(AppFormat.currency(value),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }),
      ],
    );
  }
}
