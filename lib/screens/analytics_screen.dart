// ============================================================
// screens/analytics_screen.dart  –  Period Comparison Analytics
// ============================================================
// Lets the business owner compare two years side by side —
// Income, Expenses, Sales Revenue, COGS, Gross Profit, Net Profit
// — with percentage change, plus a month-by-month trend chart for
// both years overlaid so seasonal patterns and growth are easy to
// spot at a glance.
// ============================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../database/database_helper.dart';
import '../utils/utils.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _YearData {
  double income = 0;
  double expenses = 0;
  double salesRevenue = 0;
  double cogs = 0;
  Map<String, double> incomeByMonth = {};
  Map<String, double> expensesByMonth = {};

  double get grossProfit => income - cogs;
  double get netProfit => grossProfit - expenses;
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<int> _availableYears = [];
  late int _yearA;
  late int _yearB;
  _YearData? _dataA;
  _YearData? _dataB;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().year;
    _yearA = now;
    _yearB = now - 1;
    _load();
  }

  Future<_YearData> _loadYear(int year) async {
    final db = DatabaseHelper.instance;
    final results = await Future.wait([
      db.getMonthlyIncomeBreakdown(year),
      db.getMonthlyExpenseBreakdown(year),
      db.getMonthlySalesBreakdown(year),
      db.getMonthlyCogsBreakdown(year),
    ]);

    final incomeRows = results[0];
    final expenseRows = results[1];
    final salesRows = results[2];
    final cogsRows = results[3];

    final data = _YearData();
    data.incomeByMonth = {for (var r in incomeRows) r['month'] as String: (r['total'] as num).toDouble()};
    data.expensesByMonth = {for (var r in expenseRows) r['month'] as String: (r['total'] as num).toDouble()};
    data.income = data.incomeByMonth.values.fold(0.0, (a, b) => a + b);
    data.expenses = data.expensesByMonth.values.fold(0.0, (a, b) => a + b);
    data.salesRevenue = salesRows.fold(0.0, (s, r) => s + (r['total'] as num).toDouble());
    data.cogs = cogsRows.fold(0.0, (s, r) => s + (r['total'] as num).toDouble());
    return data;
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final years = await DatabaseHelper.instance.getYearsWithData();
    final now = DateTime.now().year;
    final yearSet = {...years, now, now - 1}..removeWhere((y) => y < 2020);
    final sortedYears = yearSet.toList()..sort((a, b) => b.compareTo(a));

    final dataA = await _loadYear(_yearA);
    final dataB = await _loadYear(_yearB);

    if (!mounted) return;
    setState(() {
      _availableYears = sortedYears;
      _dataA = dataA;
      _dataB = dataB;
      _isLoading = false;
    });
  }

  // Percentage change from B (older/baseline) to A (newer). Null
  // when there's nothing to compare against, so the UI can show
  // "—" instead of a meaningless divide-by-zero result.
  double? _percentChange(double a, double b) {
    if (b == 0) return a == 0 ? 0 : null;
    return ((a - b) / b) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Analytics')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Compare Years', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _yearDropdown(_yearA, (y) {
                        setState(() => _yearA = y);
                        _load();
                      })),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('vs', style: TextStyle(color: AppColors.textMuted)),
                      ),
                      Expanded(child: _yearDropdown(_yearB, (y) {
                        setState(() => _yearB = y);
                        _load();
                      })),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_dataA != null && _dataB != null) ...[
                    _comparisonTable(),
                    const SizedBox(height: 24),
                    const Text('Monthly Trend — Income', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    _trendChart(_dataA!.incomeByMonth, _dataB!.incomeByMonth),
                    const SizedBox(height: 24),
                    const Text('Monthly Trend — Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    _trendChart(_dataA!.expensesByMonth, _dataB!.expensesByMonth),
                    const SizedBox(height: 8),
                    _legend(),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _yearDropdown(int value, ValueChanged<int> onChanged) {
    final options = {..._availableYears, value}.toList()..sort((a, b) => b.compareTo(a));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          items: options.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
          onChanged: (y) {
            if (y != null) onChanged(y);
          },
        ),
      ),
    );
  }

  Widget _comparisonTable() {
    final a = _dataA!;
    final b = _dataB!;
    final rows = [
      ('Income', a.income, b.income),
      ('Expenses', a.expenses, b.expenses),
      ('Sales Revenue', a.salesRevenue, b.salesRevenue),
      ('COGS', a.cogs, b.cogs),
      ('Gross Profit', a.grossProfit, b.grossProfit),
      ('Net Profit', a.netProfit, b.netProfit),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(flex: 3, child: Text('', style: TextStyle(fontSize: 11))),
              Expanded(flex: 3, child: Text('$_yearA', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
              Expanded(flex: 3, child: Text('$_yearB', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
              const Expanded(flex: 2, child: Text('Δ', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
            ],
          ),
          const Divider(),
          ...rows.map((row) {
            final (label, valA, valB) = row;
            final change = _percentChange(valA, valB);
            final changeColor = change == null
                ? AppColors.textMuted
                : (change >= 0 ? AppColors.income : AppColors.expense);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                  Expanded(flex: 3, child: Text(AppFormat.amount(valA), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                  Expanded(flex: 3, child: Text(AppFormat.amount(valB), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
                  Expanded(
                    flex: 2,
                    child: Text(
                      change == null ? '—' : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: changeColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _trendChart(Map<String, double> seriesA, Map<String, double> seriesB) {
    double maxVal = 100;
    for (var m in seriesA.values) { if (m > maxVal) maxVal = m; }
    for (var m in seriesB.values) { if (m > maxVal) maxVal = m; }

    List<FlSpot> toSpots(Map<String, double> series) {
      return List.generate(12, (i) {
        final key = (i + 1).toString().padLeft(2, '0');
        return FlSpot((i + 1).toDouble(), series[key] ?? 0);
      });
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(4, 16, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: LineChart(
        LineChartData(
          minX: 1, maxX: 12,
          minY: 0, maxY: maxVal * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 1 || idx > 12) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(AppFormat.shortMonthName(idx.toString().padLeft(2, '0')),
                        style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: toSpots(seriesA),
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: toSpots(seriesB),
              isCurved: true,
              color: AppColors.gold,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(AppColors.primary, '$_yearA'),
        const SizedBox(width: 16),
        _legendDot(AppColors.gold, '$_yearB'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}
