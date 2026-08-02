// ============================================================
// screens/sales_performance_screen.dart  –  Sales Performance Report
// ============================================================
// Shows how well items are selling over a chosen period — Day,
// Week, Month, or Year — and lets the owner compare two periods
// of the same kind side by side (e.g. this month vs last month).
// The whole thing can be printed or shared as a branded PDF, and
// the PDF itself is labelled as either a Monthly or Yearly report
// depending on which period type is selected.
// ============================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../utils/document_generator.dart';

enum _PeriodType { day, week, month, year }

class SalesPerformanceScreen extends StatefulWidget {
  const SalesPerformanceScreen({super.key});

  @override
  State<SalesPerformanceScreen> createState() => _SalesPerformanceScreenState();
}

class _SalesPerformanceScreenState extends State<SalesPerformanceScreen> {
  _PeriodType _periodType = _PeriodType.month;
  DateTime _periodAAnchor = DateTime.now();
  DateTime? _periodBAnchor; // null = "not comparing"
  bool _comparing = false;

  Map<String, dynamic>? _summaryA;
  Map<String, dynamic>? _summaryB;
  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Turns a period type + anchor date into a [start, end] range ─
  (String, String, String) _rangeFor(DateTime anchor) {
    switch (_periodType) {
      case _PeriodType.day:
        final d = AppFormat.dateToString(anchor);
        return (d, d, AppFormat.displayDate(d));
      case _PeriodType.week:
        final startOfWeek = anchor.subtract(Duration(days: anchor.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        final label = 'Week of ${AppFormat.displayDate(AppFormat.dateToString(startOfWeek))}';
        return (AppFormat.dateToString(startOfWeek), AppFormat.dateToString(endOfWeek), label);
      case _PeriodType.month:
        final start = DateTime(anchor.year, anchor.month, 1);
        final end = DateTime(anchor.year, anchor.month + 1, 0);
        final label = '${AppFormat.monthName(anchor.month.toString().padLeft(2, '0'))} ${anchor.year}';
        return (AppFormat.dateToString(start), AppFormat.dateToString(end), label);
      case _PeriodType.year:
        final start = DateTime(anchor.year, 1, 1);
        final end = DateTime(anchor.year, 12, 31);
        return (AppFormat.dateToString(start), AppFormat.dateToString(end), '${anchor.year}');
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final rangeA = _rangeFor(_periodAAnchor);
    final summaryA = await DatabaseHelper.instance.getSalesSummaryForRange(rangeA.$1, rangeA.$2);

    Map<String, dynamic>? summaryB;
    if (_comparing) {
      final anchorB = _periodBAnchor ?? _previousPeriod(_periodAAnchor);
      final rangeB = _rangeFor(anchorB);
      summaryB = await DatabaseHelper.instance.getSalesSummaryForRange(rangeB.$1, rangeB.$2);
      _periodBAnchor ??= anchorB;
    }

    if (!mounted) return;
    setState(() {
      _summaryA = summaryA;
      _summaryB = summaryB;
      _isLoading = false;
    });
  }

  DateTime _previousPeriod(DateTime anchor) {
    switch (_periodType) {
      case _PeriodType.day:
        return anchor.subtract(const Duration(days: 1));
      case _PeriodType.week:
        return anchor.subtract(const Duration(days: 7));
      case _PeriodType.month:
        return DateTime(anchor.year, anchor.month - 1, 1);
      case _PeriodType.year:
        return DateTime(anchor.year - 1, 1, 1);
    }
  }

  Future<void> _pickAnchor({required bool isPeriodA}) async {
    final current = isPeriodA ? _periodAAnchor : (_periodBAnchor ?? _previousPeriod(_periodAAnchor));
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isPeriodA) {
        _periodAAnchor = picked;
      } else {
        _periodBAnchor = picked;
      }
    });
    _load();
  }

  String get _reportLabel {
    switch (_periodType) {
      case _PeriodType.month:
        return 'Monthly Sales Performance Report';
      case _PeriodType.year:
        return 'Yearly Sales Performance Report';
      case _PeriodType.week:
        return 'Weekly Sales Performance Report';
      case _PeriodType.day:
        return 'Daily Sales Performance Report';
    }
  }

  Future<void> _exportPdf({required bool share}) async {
    if (_summaryA == null) return;
    setState(() => _isExporting = true);
    try {
      final profile = context.read<ProfileProvider>().profile;
      final labelA = _rangeFor(_periodAAnchor).$3;
      final String? labelB = _comparing && _periodBAnchor != null ? _rangeFor(_periodBAnchor!).$3 : null;

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (ctx) => ctx.pageNumber == 1 ? buildLetterhead(profile, _reportLabel) : pw.SizedBox(),
          footer: (ctx) => buildFooter(profile, ctx),
          build: (ctx) => [
            _pdfSummarySection(labelA, _summaryA!),
            if (_comparing && _summaryB != null) ...[
              pw.SizedBox(height: 16),
              _pdfSummarySection(labelB ?? 'Previous Period', _summaryB!),
              pw.SizedBox(height: 16),
              _pdfComparisonSection(labelA, _summaryA!, labelB ?? 'Previous Period', _summaryB!),
            ],
          ],
        ),
      );

      final bytes = await pdf.save();
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: 'Sales_Performance_${AppFormat.today()}.pdf');
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  pw.Widget _pdfSummarySection(String label, Map<String, dynamic> summary) {
    final items = summary['items'] as List;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
          'Units Sold: ${summary['totalQuantity']}    Revenue: ${AppFormat.pdfCurrency(summary['totalRevenue'])}    Transactions: ${summary['transactionCount']}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 8),
        if (items.isNotEmpty)
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1.5)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Item', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Qty', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Revenue', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              ...items.map((it) => pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(it['name'], style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${it['qty']}', style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(AppFormat.pdfCurrency(it['revenue']), style: const pw.TextStyle(fontSize: 9))),
                  ])),
            ],
          )
        else
          pw.Text('No sales recorded in this period.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
      ],
    );
  }

  pw.Widget _pdfComparisonSection(String labelA, Map<String, dynamic> a, String labelB, Map<String, dynamic> b) {
    final revA = a['totalRevenue'] as double;
    final revB = b['totalRevenue'] as double;
    final change = revB == 0 ? 0.0 : ((revA - revB) / revB) * 100;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(),
        pw.Text('Comparison', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
          '$labelA revenue ${change >= 0 ? "increased" : "decreased"} by ${change.abs().toStringAsFixed(1)}% compared to $labelB '
          '(${AppFormat.pdfCurrency(revA)} vs ${AppFormat.pdfCurrency(revB)}).',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelA = _rangeFor(_periodAAnchor).$3;
    final labelB = _comparing && _periodBAnchor != null ? _rangeFor(_periodBAnchor!).$3 : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sales Performance'),
        actions: [
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print_outlined),
            onPressed: (_isExporting || _summaryA == null) ? null : () => _exportPdf(share: false),
          ),
          IconButton(
            tooltip: 'Share',
            icon: _isExporting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.share_outlined),
            onPressed: (_isExporting || _summaryA == null) ? null : () => _exportPdf(share: true),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Period type selector (classifies the report as
          // Daily/Weekly/Monthly/Yearly) ─────────────────────
          Wrap(
            spacing: 8,
            children: _PeriodType.values.map((type) {
              final isSelected = type == _periodType;
              return ChoiceChip(
                label: Text(type.name[0].toUpperCase() + type.name.substring(1)),
                selected: isSelected,
                selectedColor: AppColors.gold,
                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontSize: 12),
                onSelected: (_) {
                  setState(() => _periodType = type);
                  _load();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Compare to another period', style: TextStyle(fontSize: 13)),
            value: _comparing,
            activeColor: AppColors.gold,
            onChanged: (val) {
              setState(() => _comparing = val);
              _load();
            },
          ),

          InkWell(
            onTap: () => _pickAnchor(isPeriodA: true),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Period A', border: OutlineInputBorder()),
              child: Text(labelA),
            ),
          ),
          if (_comparing) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _pickAnchor(isPeriodA: false),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Period B', border: OutlineInputBorder()),
                child: Text(labelB ?? 'Previous period'),
              ),
            ),
          ],
          const SizedBox(height: 20),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_summaryA != null) ...[
            _summaryCard(labelA, _summaryA!, AppColors.gold),
            if (_comparing && _summaryB != null) ...[
              const SizedBox(height: 12),
              _summaryCard(labelB ?? 'Previous Period', _summaryB!, AppColors.primary),
              const SizedBox(height: 16),
              _comparisonChart(labelA, _summaryA!, labelB ?? 'Previous', _summaryB!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _summaryCard(String label, Map<String, dynamic> summary, Color accent) {
    final items = summary['items'] as List;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: accent)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat('Units Sold', '${summary['totalQuantity']}'),
              _stat('Revenue', AppFormat.currency(summary['totalRevenue'])),
              _stat('Transactions', '${summary['transactionCount']}'),
            ],
          ),
          if (items.isNotEmpty) ...[
            const Divider(height: 20),
            const Text('Top Items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...items.take(5).map((it) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(it['name'], style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                      Text('${it['qty']} sold', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(width: 8),
                      Text(AppFormat.currency(it['revenue']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No sales recorded in this period.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _comparisonChart(String labelA, Map<String, dynamic> a, String labelB, Map<String, dynamic> b) {
    final revA = a['totalRevenue'] as double;
    final revB = b['totalRevenue'] as double;
    final maxY = [revA, revB].reduce((x, y) => x > y ? x : y) * 1.25 + 1;
    final change = revB == 0 ? 0.0 : ((revA - revB) / revB) * 100;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            '${change >= 0 ? "▲" : "▼"} ${change.abs().toStringAsFixed(1)}% vs $labelB',
            style: TextStyle(fontSize: 12, color: change >= 0 ? AppColors.income : AppColors.expense, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: revA, color: AppColors.gold, width: 32)]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: revB, color: AppColors.primary, width: 32)]),
                ],
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(value == 0 ? labelA : labelB,
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
