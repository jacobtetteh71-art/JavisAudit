// ============================================================
// screens/dashboard_screen.dart  –  Step 4: Dashboard / Home
// ============================================================
// The landing screen for returning users. Shows live KPI cards
// computed from SQLite, a 6-month income vs expense bar chart,
// the VAT progress bar, and the 10 most recent transactions.
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../database/database_helper.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'profile_picture_picker.dart';
import 'global_search_screen.dart';
import 'help_manual_screen.dart';
import '../utils/page_transitions.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  const DashboardScreen({super.key, this.onMenuTap});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Local state for values that don't have their own provider
  double _monthlyIncome = 0;
  double _monthlyExpenses = 0;
  double _monthlyCogs = 0;
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _incomeChartData = [];
  List<Map<String, dynamic>> _expenseChartData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();

    // Auto-refresh the dashboard whenever Income, Expenses, or Sales
    // change anywhere else in the app (add/edit/delete/payment),
    // instead of only refreshing when this screen is first opened.
    context.read<IncomeProvider>().addListener(_loadDashboardData);
    context.read<ExpenseProvider>().addListener(_loadDashboardData);
    context.read<SalesProvider>().addListener(_loadDashboardData);
  }

  @override
  void dispose() {
    context.read<IncomeProvider>().removeListener(_loadDashboardData);
    context.read<ExpenseProvider>().removeListener(_loadDashboardData);
    context.read<SalesProvider>().removeListener(_loadDashboardData);
    super.dispose();
  }

  // ── _loadDashboardData ─────────────────────────────────────
  // Runs multiple database queries in parallel using Future.wait
  // for faster loading than awaiting them one at a time.
  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final db = DatabaseHelper.instance;
    final currentYear = DateTime.now().year;

    // Future.wait runs all these queries simultaneously
    final results = await Future.wait([
      db.getMonthlyIncome(),
      db.getMonthlyExpenses(),
      db.getRecentTransactions(),
      db.getMonthlyIncomeBreakdown(currentYear),
      db.getMonthlyExpenseBreakdown(currentYear),
      db.getMonthlyCogs(),
    ]);

    if (!mounted) return;

    setState(() {
      _monthlyIncome       = results[0] as double;
      _monthlyExpenses     = results[1] as double;
      _recentTransactions  = results[2] as List<Map<String, dynamic>>;
      _incomeChartData     = results[3] as List<Map<String, dynamic>>;
      _expenseChartData    = results[4] as List<Map<String, dynamic>>;
      _monthlyCogs         = results[5] as double;
      _isLoading = false;
    });

    // Also refresh the VAT provider's turnover figure
    if (mounted) {
      await context.read<VatProvider>().loadTurnover();
    }
  }

  // Pull-to-refresh handler
  Future<void> _onRefresh() async {
    await _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the profile provider so the greeting updates if the
    // business name changes
    final profile = context.watch<ProfileProvider>().profile;
    final vat = context.watch<VatProvider>();

    final grossProfit = _monthlyIncome - _monthlyCogs;
    final trueNetProfit = grossProfit - _monthlyExpenses;
    final grossMarginPercent = _monthlyIncome <= 0 ? 0.0 : (grossProfit / _monthlyIncome) * 100;
    final netMarginPercent = _monthlyIncome <= 0 ? 0.0 : (trueNetProfit / _monthlyIncome) * 100;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: widget.onMenuTap,
        ),
        title: Text(profile?.businessName ?? 'JavisAudit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help & User Manual',
            onPressed: () => Navigator.of(context).push(
              slideFromRight(const HelpManualScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => showProfilePicturePicker(context),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                backgroundImage: (profile?.profileImagePath != null &&
                        File(profile!.profileImagePath!).existsSync())
                    ? FileImage(File(profile.profileImagePath!))
                    : null,
                child: (profile?.profileImagePath == null ||
                        !File(profile!.profileImagePath!).existsSync())
                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                // AlwaysScrollable ensures pull-to-refresh works even
                // when content is shorter than the screen
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Greeting ─────────────────────────────
                    Text(
                      'Hello, ${profile?.ownerName.split(" ").first ?? "there"} 👋',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      AppFormat.displayDate(AppFormat.today()),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),

                    // ── KPI Cards Row 1 ──────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _kpiCard(
                            label: 'Monthly Income',
                            value: AppFormat.currency(_monthlyIncome),
                            icon: Icons.trending_up,
                            color: AppColors.income,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _kpiCard(
                            label: 'Monthly Expenses',
                            value: AppFormat.currency(_monthlyExpenses),
                            icon: Icons.trending_down,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Net Profit Card (full width) ─────────
                    _kpiCard(
                      label: 'Net Profit (This Month)',
                      value: AppFormat.currency(trueNetProfit),
                      icon: trueNetProfit >= 0 ? Icons.check_circle : Icons.warning,
                      color: trueNetProfit >= 0 ? AppColors.income : AppColors.expense,
                      fullWidth: true,
                    ),
                    const SizedBox(height: 12),

                    // ── Gross Profit + Margins Row ────────────
                    Row(
                      children: [
                        Expanded(
                          child: _kpiCard(
                            label: 'Gross Profit',
                            value: AppFormat.currency(grossProfit),
                            icon: Icons.point_of_sale_outlined,
                            color: grossProfit >= 0 ? AppColors.gold : AppColors.expense,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _marginsCard(grossMarginPercent, netMarginPercent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── VAT Progress Card ────────────────────
                    _vatProgressCard(vat),
                    const SizedBox(height: 20),

                    // ── 6-Month Chart ─────────────────────────
                    const Text(
                      'Income vs Expenses (6 Months)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    _buildBarChart(),
                    const SizedBox(height: 24),

                    // ── Recent Transactions ───────────────────
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    _recentTransactions.isEmpty
                        ? _emptyState('No transactions yet. Start by adding income or an expense!')
                        : Column(
                            children: _recentTransactions
                                .map((t) => _transactionTile(t))
                                .toList(),
                          ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ── _marginsCard: shows Gross & Net margin % side by side ──
  Widget _marginsCard(double grossMarginPercent, double netMarginPercent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profit Margins', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gross', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Text('${grossMarginPercent.toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.gold)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Net', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Text('${netMarginPercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: netMarginPercent >= 0 ? AppColors.income : AppColors.expense)),
            ],
          ),
        ],
      ),
    );
  }

  // ── _kpiCard: reusable summary card widget ─────────────────
  Widget _kpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // FittedBox shrinks long numbers to fit the card width
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── _vatProgressCard: shows the VAT threshold progress bar ──
  Widget _vatProgressCard(VatProvider vat) {
    // Pick a colour based on the current alert level
    Color barColor;
    switch (vat.alertLevel) {
      case 'exceeded':
      case 'critical':
        barColor = AppColors.expense;
        break;
      case 'warning':
        barColor = AppColors.warning;
        break;
      default:
        barColor = AppColors.income;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'VAT Threshold Progress',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                vat.percentageString,
                style: TextStyle(fontWeight: FontWeight.bold, color: barColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ClipRRect rounds the corners of the progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: vat.percentageReached,
              minHeight: 10,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${AppFormat.currency(vat.annualTurnover)} of GH₵ 750,000.00',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── _buildBarChart: fl_chart bar chart for income vs expense ─
  Widget _buildBarChart() {
    // Build a lookup map: month number → amount, for both datasets
    final Map<String, double> incomeMap = {
      for (var row in _incomeChartData)
        row['month'] as String: (row['total'] as num).toDouble()
    };
    final Map<String, double> expenseMap = {
      for (var row in _expenseChartData)
        row['month'] as String: (row['total'] as num).toDouble()
    };

    // Determine the last 6 months to display (e.g., Jan–Jun)
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final monthNum = now.month - 5 + i;
      // Handle wrap-around to previous year if needed
      final adjusted = monthNum <= 0 ? monthNum + 12 : monthNum;
      return adjusted.toString().padLeft(2, '0');
    });

    // Find the maximum value to scale the Y axis nicely
    double maxVal = 100;
    for (var m in months) {
      maxVal = [maxVal, incomeMap[m] ?? 0, expenseMap[m] ?? 0]
          .reduce((a, b) => a > b ? a : b);
    }

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxVal * 1.2, // Add 20% headroom above tallest bar
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            // Bottom axis shows month abbreviations
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= months.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      AppFormat.shortMonthName(months[idx]),
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          // Build one BarChartGroupData per month — each group has
          // 2 bars side-by-side: income (green) and expense (red)
          barGroups: List.generate(months.length, (i) {
            final m = months[i];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: incomeMap[m] ?? 0,
                  color: AppColors.income,
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                ),
                BarChartRodData(
                  toY: expenseMap[m] ?? 0,
                  color: AppColors.expense,
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── _transactionTile: one row in the recent transactions list ─
  Widget _transactionTile(Map<String, dynamic> txn) {
    final bool isIncome = txn['type'] == 'Income';
    final double amount = (txn['amount'] as num).toDouble();

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
          // Coloured icon circle indicating income or expense
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isIncome ? AppColors.income : AppColors.expense)
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              size: 18,
              color: isIncome ? AppColors.income : AppColors.expense,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn['description'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  AppFormat.displayDate(txn['date'] as String),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? "+" : "-"}${AppFormat.currency(amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isIncome ? AppColors.income : AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }

  // ── _emptyState: shown when there's no data to display ──────
  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 36, color: AppColors.textLight),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
