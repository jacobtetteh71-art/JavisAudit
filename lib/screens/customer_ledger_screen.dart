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
  Map<String, Map<String, dynamic>> _contacts = {}; // name -> customers row
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final rows = await DatabaseHelper.instance.getCustomerLedger();
    final customers = await DatabaseHelper.instance.getCustomers();
    if (!mounted) return;
    setState(() {
      _ledger = rows;
      _contacts = {for (var c in customers) c['name'] as String: c};
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
    final phone = _contacts[name]?['phone'] as String?;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => _CustomerDetailScreen(customerName: name)))
          .then((_) => _load()),
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
                  if (phone != null && phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 11, color: AppColors.textLight),
                        const SizedBox(width: 3),
                        Text(phone, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                      ],
                    ),
                  ],
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
  Customer? _customer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DatabaseHelper.instance.getSalesForCustomer(widget.customerName);
    final customerRow = await DatabaseHelper.instance.getCustomerByName(widget.customerName);
    if (!mounted) return;
    setState(() {
      _sales = rows.map((r) => Sale.fromMap(r)).toList();
      _customer = customerRow != null ? Customer.fromMap(customerRow) : null;
      _isLoading = false;
    });
  }

  Future<void> _editContact() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditContactSheet(customerName: widget.customerName, existing: _customer),
    );
    if (result == true) _load();
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Icon(Icons.contact_phone_outlined, size: 18, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: (_customer?.phone == null && _customer?.email == null)
                            ? const Text('No contact details saved', style: TextStyle(fontSize: 12, color: AppColors.textMuted))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_customer?.phone != null && _customer!.phone!.isNotEmpty)
                                    Text(_customer!.phone!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  if (_customer?.email != null && _customer!.email!.isNotEmpty)
                                    Text(_customer!.email!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                ],
                              ),
                      ),
                      TextButton(
                        onPressed: _editContact,
                        child: Text(_customer == null ? 'Add Contact' : 'Edit'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
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

// ============================================================
// _EditContactSheet  –  Add/edit a customer's phone & email
// ============================================================
class _EditContactSheet extends StatefulWidget {
  final String customerName;
  final Customer? existing;
  const _EditContactSheet({required this.customerName, this.existing});

  @override
  State<_EditContactSheet> createState() => _EditContactSheetState();
}

class _EditContactSheetState extends State<_EditContactSheet> {
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.existing?.email ?? '');
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final data = {
      'name':       widget.customerName,
      'phone':      _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'email':      _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      'created_at': widget.existing == null ? DateTime.now().toIso8601String() : widget.existing!.createdAt,
    };

    if (widget.existing != null && widget.existing!.id != null) {
      await DatabaseHelper.instance.updateCustomer(widget.existing!.id!, data);
    } else {
      await DatabaseHelper.instance.insertCustomer(data);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Contact for ${widget.customerName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Contact'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
