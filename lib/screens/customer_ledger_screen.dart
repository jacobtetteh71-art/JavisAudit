// ============================================================
// screens/customer_ledger_screen.dart  –  Customer Ledger
// ============================================================
// Aggregates every sale by customer name so the owner can see,
// at a glance, who owes what in total — instead of hunting
// through individual sales one at a time. Tapping a customer
// drills down into their full sales history.
// ============================================================

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import 'sales_screen.dart';

class CustomerLedgerScreen extends StatefulWidget {
  const CustomerLedgerScreen({super.key});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _ledger = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final rows = await DatabaseHelper.instance.getCustomerLedger();
    if (!mounted) return;
    setState(() {
      _ledger = rows;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalOwed = _ledger.fold<double>(
      0, (sum, row) => sum + ((row['total_balance'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Customer Ledger')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ledger.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No customer names have been recorded on any sales yet. '
                      'Add a customer name when recording a sale to start tracking balances here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── Summary card ─────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Owed to You',
                                style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              AppFormat.currency(totalOwed),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text('${_ledger.where((r) => ((r['total_balance'] as num?) ?? 0) > 0).length} '
                                'customer(s) with an outstanding balance',
                                style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      ..._ledger.map((row) => _CustomerTile(row: row)),
                    ],
                  ),
                ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Map<String, dynamic> row;
  const _CustomerTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final name = row['customer_name'] as String? ?? 'Unknown';
    final totalSales = (row['total_sales'] as num?)?.toDouble() ?? 0;
    final totalPaid = (row['total_paid'] as num?)?.toDouble() ?? 0;
    final balance = (row['total_balance'] as num?)?.toDouble() ?? 0;
    final saleCount = row['sale_count'] as int? ?? 0;
    final hasBalance = balance > 0.01;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: hasBalance ? AppColors.expenseLight : AppColors.primaryLight,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
                color: hasBalance ? AppColors.expense : AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '$saleCount sale${saleCount == 1 ? '' : 's'} • Total: ${AppFormat.currency(totalSales)} '
          '• Paid: ${AppFormat.currency(totalPaid)}',
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              hasBalance ? AppFormat.currency(balance) : 'Settled',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: hasBalance ? AppColors.expense : AppColors.primary,
                fontSize: hasBalance ? 14 : 12,
              ),
            ),
            if (hasBalance)
              const Text('owed', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _CustomerSalesScreen(customerName: name)),
        ),
      ),
    );
  }
}

// ============================================================
// _CustomerSalesScreen  –  Drill-down: all sales for one customer
// ============================================================
class _CustomerSalesScreen extends StatefulWidget {
  final String customerName;
  const _CustomerSalesScreen({required this.customerName});

  @override
  State<_CustomerSalesScreen> createState() => _CustomerSalesScreenState();
}

class _CustomerSalesScreenState extends State<_CustomerSalesScreen> {
  bool _isLoading = true;
  List<Sale> _sales = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final rows = await DatabaseHelper.instance.getSalesForCustomer(widget.customerName);
    if (!mounted) return;
    setState(() {
      _sales = rows.map((r) => Sale.fromMap(r)).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.customerName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sales.length,
                itemBuilder: (context, index) {
                  final sale = _sales[index];
                  final statusColor = sale.paymentStatus == 'Paid'
                      ? AppColors.income
                      : (sale.paymentStatus == 'Pending' ? AppColors.expense : AppColors.warning);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListTile(
                      title: Text(sale.itemDescription,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text(
                        '${AppFormat.displayDate(sale.date)} • ${sale.paymentStatus}'
                        '${sale.balance > 0 ? " • Balance: ${AppFormat.currency(sale.balance)}" : ""}',
                        style: TextStyle(fontSize: 11, color: statusColor),
                      ),
                      trailing: Text(
                        AppFormat.currency(sale.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold),
                      ),
                      onTap: () {
                        // Reuse the exact same detail sheet from the Sales tab —
                        // opening it here lets the owner record a payment straight
                        // from the ledger, then refresh this list on close.
                        showSaleDetailSheet(context, sale);
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
