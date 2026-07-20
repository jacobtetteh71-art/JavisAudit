// ============================================================
// screens/customer_ledger_screen.dart  –  Who Owes What
// ============================================================
// Aggregates every sale by customer name, so the owner can see at
// a glance who's fully paid up and who still owes a balance —
// without having to scroll through every individual sale.
// ============================================================

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/models.dart';
import '../utils/utils.dart';

class CustomerLedgerScreen extends StatefulWidget {
  const CustomerLedgerScreen({super.key});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  List<Map<String, dynamic>> _ledger = [];
  bool _isLoading = true;

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
    final totalOwed = _ledger.fold<double>(0, (s, r) => s + (r['balance_owed'] as num).toDouble());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Customer Ledger')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _ledger.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text('No customers on record yet.\nAdd a customer name on a sale to start tracking balances.',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.expenseLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Owed to You', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                              Text(AppFormat.currency(totalOwed),
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.expense)),
                              const SizedBox(height: 2),
                              Text('Across ${_ledger.where((r) => (r['balance_owed'] as num) > 0).length} customer(s)',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._ledger.map((row) => _customerTile(row)),
                      ],
                    ),
            ),
    );
  }

  Widget _customerTile(Map<String, dynamic> row) {
    final name = row['customer_name'] as String;
    final balance = (row['balance_owed'] as num).toDouble();
    final totalSales = (row['total_sales'] as num).toDouble();
    final txCount = row['transaction_count'] as int;
    final hasBalance = balance > 0.01;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _CustomerDetailScreen(customerName: name)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: (hasBalance ? AppColors.expense : AppColors.income).withOpacity(0.12),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: hasBalance ? AppColors.expense : AppColors.income, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('$txCount sale(s) • ${AppFormat.currency(totalSales)} total',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hasBalance ? AppFormat.currency(balance) : 'Paid up',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: hasBalance ? 14 : 12,
                      color: hasBalance ? AppColors.expense : AppColors.income),
                ),
                if (hasBalance)
                  const Text('owed', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// _CustomerDetailScreen  –  Every sale for one customer
// ============================================================
class _CustomerDetailScreen extends StatefulWidget {
  final String customerName;
  const _CustomerDetailScreen({required this.customerName});

  @override
  State<_CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<_CustomerDetailScreen> {
  List<Sale> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DatabaseHelper.instance.getSalesForCustomer(widget.customerName);
    if (!mounted) return;
    setState(() {
      _sales = rows.map((r) => Sale.fromMap(r)).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final balance = _sales.fold<double>(0, (s, sale) => s + sale.balance);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.customerName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: balance > 0.01 ? AppColors.expenseLight : AppColors.primaryLight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Balance Owed', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(AppFormat.currency(balance),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: balance > 0.01 ? AppColors.expense : AppColors.income)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _sales.length,
                    itemBuilder: (_, index) {
                      final sale = _sales[index];
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sale.itemDescription, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text('${AppFormat.displayDate(sale.date)} • ${sale.paymentStatus}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            Text(AppFormat.currency(sale.totalAmount),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
