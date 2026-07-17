// ============================================================
// screens/sales_screen.dart  –  Step 7: Record Sales
// ============================================================
// More granular than Income: captures customer, item, quantity,
// and unit price, with the total auto-calculated live as the
// user types. If payment_status = 'Paid', the SalesProvider
// automatically creates a matching Income entry behind the
// scenes (see providers/providers.dart → SalesProvider.addSale).
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().loadAll();
    });
  }

  void _openAddSaleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddSaleSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesProvider>();
    final sales = provider.sales;
    final totalSales = sales.fold<double>(0, (sum, s) => sum + s.totalAmount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Sales')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSaleSheet,
        backgroundColor: AppColors.gold,
        icon: const Icon(Icons.add),
        label: const Text('Record Sale'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: AppColors.goldLight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Sales',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Text(
                        AppFormat.currency(totalSales),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.gold),
                      ),
                      const SizedBox(height: 2),
                      Text('${sales.length} sale${sales.length == 1 ? '' : 's'} recorded',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Expanded(
                  child: sales.isEmpty
                      ? const Center(
                          child: Text('No sales recorded yet.',
                              style: TextStyle(color: AppColors.textMuted)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                          itemCount: sales.length,
                          itemBuilder: (_, index) => _SaleListTile(sale: sales[index]),
                        ),
                ),
              ],
            ),
    );
  }
}

class _SaleListTile extends StatelessWidget {
  final Sale sale;
  const _SaleListTile({required this.sale});

  // Returns a colour depending on payment status
  Color _statusColor() {
    switch (sale.paymentStatus) {
      case 'Paid':
        return AppColors.income;
      case 'Pending':
        return AppColors.expense;
      default: // Partial Payment
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(sale.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete this sale?'),
                content: Text('Delete sale of "${sale.itemDescription}"? This cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => context.read<SalesProvider>().deleteSale(sale.id!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(sale.itemDescription,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    sale.paymentStatus,
                    style: TextStyle(fontSize: 10, color: _statusColor(), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (sale.customerName != null && sale.customerName!.isNotEmpty)
              Text('Customer: ${sale.customerName}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            Text(
              '${sale.quantity} × ${AppFormat.currency(sale.unitPrice)}  •  ${AppFormat.displayDate(sale.date)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                AppFormat.currency(sale.totalAmount),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSaleSheet extends StatefulWidget {
  const _AddSaleSheet();

  @override
  State<_AddSaleSheet> createState() => _AddSaleSheetState();
}

class _AddSaleSheetState extends State<_AddSaleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _customerCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _unitPriceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedPaymentMethod;
  String _selectedStatus = 'Paid'; // Default to Paid
  bool _isSaving = false;

  // The live-calculated total — recomputed on every keystroke
  double get _computedTotal {
    final qty = int.tryParse(_quantityCtrl.text) ?? 0;
    final price = double.tryParse(_unitPriceCtrl.text) ?? 0;
    return qty * price;
  }

  @override
  void initState() {
    super.initState();
    // Listen to changes in quantity/price so the total updates live
    _quantityCtrl.addListener(() => setState(() {}));
    _unitPriceCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _itemCtrl.dispose();
    _quantityCtrl.dispose();
    _unitPriceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPaymentMethod == null) {
      _showError('Please select a payment method.');
      return;
    }

    setState(() => _isSaving = true);

    final sale = Sale(
      date:             AppFormat.dateToString(_selectedDate),
      customerName:     _customerCtrl.text.trim().isEmpty ? null : _customerCtrl.text.trim(),
      itemDescription:  _itemCtrl.text.trim(),
      quantity:         int.parse(_quantityCtrl.text.trim()),
      unitPrice:        double.parse(_unitPriceCtrl.text.trim()),
      totalAmount:      _computedTotal,
      paymentMethod:    _selectedPaymentMethod!,
      paymentStatus:    _selectedStatus,
      notes:            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt:        DateTime.now().toIso8601String(),
    );

    // SalesProvider.addSale() automatically creates a matching
    // income entry if paymentStatus == 'Paid' — see providers.dart
    final success = await context.read<SalesProvider>().addSale(sale);

    // Refresh VAT tracker since a Paid sale adds to annual turnover
    if (success && mounted) {
      await context.read<VatProvider>().loadTurnover();
    }

    setState(() => _isSaving = false);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale recorded successfully!'), backgroundColor: AppColors.primary),
      );
    } else {
      _showError('Failed to save. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Record a Sale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date *', border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(AppFormat.displayDate(AppFormat.dateToString(_selectedDate))),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _customerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name (optional)', border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _itemCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item / Service *', hintText: 'e.g., 2 yards of Ankara fabric',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 2) return 'Enter the item or service sold';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Quantity and Unit Price side by side
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity *', border: OutlineInputBorder()),
                        validator: (val) {
                          final q = int.tryParse(val ?? '');
                          if (q == null || q <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Unit Price *', prefixText: 'GH₵ ', border: OutlineInputBorder()),
                        validator: (val) {
                          final p = double.tryParse(val ?? '');
                          if (p == null || p <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Live-calculated total display ──────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.goldLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w600)),
                      // This text rebuilds automatically because we call
                      // setState() in the controller listeners above
                      Text(
                        AppFormat.currency(_computedTotal),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.gold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _selectedPaymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment Method *', border: OutlineInputBorder()),
                  items: Income.paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _selectedPaymentMethod = val),
                ),
                const SizedBox(height: 12),

                // ── Payment status segmented control ────────────
                const Text('Payment Status *', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: Sale.paymentStatuses.map((status) {
                    final isSelected = status == _selectedStatus;
                    return ChoiceChip(
                      label: Text(status, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
                      onSelected: (_) => setState(() => _selectedStatus = status),
                    );
                  }).toList(),
                ),
                if (_selectedStatus == 'Paid')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'ℹ️ This will also be added to your Income records automatically.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                    ),
                  ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Sale'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
