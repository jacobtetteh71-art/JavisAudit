// ============================================================
// screens/vat_tracker_screen.dart  –  Step 9: VAT Tracker
// ============================================================
// The flagship feature of JavisAudit. Shows cumulative annual
// turnover against the GRA's GHS 750,000 threshold, a monthly
// breakdown table, and a static information box explaining
// what GRA VAT registration involves.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';

class VatTrackerScreen extends StatefulWidget {
  const VatTrackerScreen({super.key});

  @override
  State<VatTrackerScreen> createState() => _VatTrackerScreenState();
}

class _VatTrackerScreenState extends State<VatTrackerScreen> {
  List<Map<String, dynamic>> _monthlyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Refresh the cumulative turnover figure
    await context.read<VatProvider>().loadTurnover();

    // Get the 12-month breakdown for the table
    final currentYear = DateTime.now().year;
    final data = await DatabaseHelper.instance.getMonthlyIncomeBreakdown(currentYear);

    if (!mounted) return;
    setState(() {
      _monthlyData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vat = context.watch<VatProvider>();

    // Determine status badge text and colour based on alert level
    String statusText;
    Color statusColor;
    switch (vat.alertLevel) {
      case 'exceeded':
        statusText = 'THRESHOLD EXCEEDED';
        statusColor = AppColors.expense;
        break;
      case 'critical':
        statusText = 'CRITICAL — 90%+';
        statusColor = AppColors.expense;
        break;
      case 'warning':
        statusText = 'WARNING — 70%+';
        statusColor = AppColors.warning;
        break;
      default:
        statusText = 'SAFE';
        statusColor = AppColors.income;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('VAT Tracker')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Status badge ─────────────────────────
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                            color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Big progress circle/bar card ─────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          vat.percentageString,
                          style: TextStyle(
                              fontSize: 42, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                        const Text('of GRA VAT threshold reached',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: vat.percentageReached,
                            minHeight: 16,
                            backgroundColor: AppColors.background,
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppFormat.currency(vat.annualTurnover),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Text(
                              'GH₵ 750,000.00',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Monthly turnover table ────────────────
                  const Text('Monthly Turnover (This Year)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  _monthlyTable(),
                  const SizedBox(height: 20),

                  // ── GRA Information box ───────────────────
                  _graInfoBox(),
                ],
              ),
            ),
    );
  }

  // ── _monthlyTable: 12-row breakdown of income by month ──────
  Widget _monthlyTable() {
    // Build a full 12-month list, filling missing months with 0
    final Map<String, double> dataMap = {
      for (var row in _monthlyData)
        row['month'] as String: (row['total'] as num).toDouble()
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(12, (i) {
          final monthKey = (i + 1).toString().padLeft(2, '0');
          final amount = dataMap[monthKey] ?? 0.0;
          final isLast = i == 11;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppFormat.monthName(monthKey), style: const TextStyle(fontSize: 13)),
                Text(
                  AppFormat.currency(amount),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: amount > 0 ? FontWeight.w600 : FontWeight.normal,
                    color: amount > 0 ? AppColors.textPrimary : AppColors.textLight,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── _graInfoBox: static regulatory information ───────────────
  Widget _graInfoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: AppColors.info, size: 18),
              SizedBox(width: 6),
              Text('GRA VAT Information',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.info)),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow('VAT Registration Threshold', 'GHS 750,000 per year'),
          _infoRow('Legal Basis', 'Ghana VAT Act (Act 870, amended by Act 1151, 2023)'),
          _infoRow('Action Required', 'Register for VAT within 30 days of crossing the threshold'),
          _infoRow('After Registration', 'Charge 15% standard VAT; file returns monthly or quarterly'),
          _infoRow('Penalty', 'Failure to register is a criminal offence under the VAT Act'),
          _infoRow('GRA Contact', '0800-900-110 (Toll Free) | www.gra.gov.gh'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
