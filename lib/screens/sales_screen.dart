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
import '../utils/receipt_generator.dart';
import '../widgets/cheque_details_fields.dart';
import 'verify_identity_sheet.dart';

// Public entry point so other screens (Customer Ledger, Global
// Search) can open the same sale detail view used here, without
// duplicating the whole _SaleDetailSheet widget.
void showSaleDetailSheet(BuildContext context, Sale sale) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SaleDetailSheet(sale: sale),
  );
}

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
        final confirmedIntent = await showDialog<bool>(
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

        if (!confirmedIntent) return false;
        if (!context.mounted) return false;
        return await verifyIdentity(context, reason: 'delete this sale');
      },
      onDismissed: (_) => context.read<SalesProvider>().deleteSale(sale.id!),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _SaleDetailSheet(sale: sale),
        ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (sale.paymentStatus != 'Paid')
                  Text(
                    'Balance: ${AppFormat.currency(sale.balance)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.expense, fontWeight: FontWeight.w600),
                  )
                else
                  const SizedBox.shrink(),
                Text(
                  AppFormat.currency(sale.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.gold),
                ),
              ],
            ),
          ],
        ),
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
  final _amountPaidCtrl = TextEditingController(); // Only shown for Partial Payment
  final _costPriceCtrl = TextEditingController(); // Optional — powers gross profit

  DateTime _selectedDate = DateTime.now();
  String? _selectedPaymentMethod;
  String _selectedStatus = 'Paid'; // Default to Paid
  bool _isSaving = false;
  final _chequeDetails = ChequeDetailsController();
  InventoryItem? _selectedInventoryItem; // Optional — links this sale to tracked stock

  // The live-calculated total — recomputed on every keystroke
  double get _computedTotal {
    final qty = int.tryParse(_quantityCtrl.text) ?? 0;
    final price = double.tryParse(_unitPriceCtrl.text) ?? 0;
    return qty * price;
  }

  // Live-calculated gross profit for this sale (0 if no cost entered)
  double get _computedProfit {
    final qty = int.tryParse(_quantityCtrl.text) ?? 0;
    final cost = double.tryParse(_costPriceCtrl.text) ?? 0;
    return _computedTotal - (qty * cost);
  }

  @override
  void initState() {
    super.initState();
    // Listen to changes in quantity/price so the total updates live
    _quantityCtrl.addListener(() => setState(() {}));
    _unitPriceCtrl.addListener(() => setState(() {}));
    _costPriceCtrl.addListener(() => setState(() {}));
    // Load inventory items so the "Select from Inventory" dropdown has data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _itemCtrl.dispose();
    _quantityCtrl.dispose();
    _unitPriceCtrl.dispose();
    _notesCtrl.dispose();
    _amountPaidCtrl.dispose();
    _costPriceCtrl.dispose();
    _chequeDetails.dispose();
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

    // For a Partial Payment, an initial amount paid so far is required
    double startingAmountPaid = 0;
    if (_selectedStatus == 'Partial Payment') {
      final entered = double.tryParse(_amountPaidCtrl.text.trim());
      if (entered == null || entered <= 0) {
        _showError('Enter how much has been paid so far.');
        return;
      }
      if (entered >= _computedTotal) {
        _showError('That covers the full amount — please choose "Paid" instead.');
        return;
      }
      startingAmountPaid = entered;
    }

    // If selling from tracked stock, make sure there's enough on hand
    if (_selectedInventoryItem != null) {
      final qty = int.tryParse(_quantityCtrl.text.trim()) ?? 0;
      if (qty > _selectedInventoryItem!.quantityOnHand) {
        _showError(
          'Only ${_selectedInventoryItem!.quantityOnHand} "${_selectedInventoryItem!.itemName}" left in stock.',
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final sale = Sale(
      date:             AppFormat.dateToString(_selectedDate),
      customerName:     _customerCtrl.text.trim().isEmpty ? null : _customerCtrl.text.trim(),
      itemDescription:  _itemCtrl.text.trim(),
      quantity:         int.parse(_quantityCtrl.text.trim()),
      unitPrice:        double.parse(_unitPriceCtrl.text.trim()),
      totalAmount:      _computedTotal,
      costPrice:        double.tryParse(_costPriceCtrl.text.trim()) ?? 0,
      paymentMethod:    _selectedPaymentMethod!,
      paymentStatus:    _selectedStatus,
      amountPaid:       startingAmountPaid,
      notes:            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      inventoryItemId:  _selectedInventoryItem?.id,
      chequeAccountNumber: _chequeDetails.toMap()['cheque_account_number'],
      chequeAccountName:   _chequeDetails.toMap()['cheque_account_name'],
      chequeNumber:        _chequeDetails.toMap()['cheque_number'],
      chequeImagePath:     _chequeDetails.imagePath,
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

                const SizedBox(height: 12),

                // ── Optional: select from tracked inventory ─────
                // Picking an item auto-fills description, unit
                // price, and cost price, and links this sale so
                // completing it reduces stock on hand.
                Consumer<InventoryProvider>(
                  builder: (context, inventoryProvider, _) {
                    if (inventoryProvider.items.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<InventoryItem?>(
                        value: _selectedInventoryItem,
                        decoration: const InputDecoration(
                          labelText: 'Select from Inventory (optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<InventoryItem?>(value: null, child: Text('None — freeform entry')),
                          ...inventoryProvider.items.map((item) => DropdownMenuItem<InventoryItem?>(
                                value: item,
                                child: Text('${item.itemName} (${item.quantityOnHand} in stock)'),
                              )),
                        ],
                        onChanged: (item) {
                          setState(() {
                            _selectedInventoryItem = item;
                            if (item != null) {
                              _itemCtrl.text = item.itemName;
                              _unitPriceCtrl.text = item.sellingPrice.toString();
                              _costPriceCtrl.text = item.costPrice.toString();
                            }
                          });
                        },
                      ),
                    );
                  },
                ),

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

                TextFormField(
                  controller: _costPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Unit Cost Price (optional)', prefixText: 'GH₵ ', border: OutlineInputBorder(),
                    helperText: 'What this item cost you — powers gross profit tracking.',
                    helperMaxLines: 2,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return null;
                    final p = double.tryParse(val);
                    if (p == null || p < 0) return 'Enter a valid cost, or leave blank';
                    return null;
                  },
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
                  child: Column(
                    children: [
                      Row(
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
                      if (_costPriceCtrl.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Gross Profit', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            Text(
                              AppFormat.currency(_computedProfit),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _computedProfit >= 0 ? AppColors.income : AppColors.expense),
                            ),
                          ],
                        ),
                      ],
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
                if (_selectedPaymentMethod == 'Cheque') ...[
                  const SizedBox(height: 12),
                  ChequeDetailsFields(controller: _chequeDetails),
                ],
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
                if (_selectedStatus == 'Partial Payment') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountPaidCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount Paid So Far *',
                      prefixText: 'GH₵ ',
                      border: OutlineInputBorder(),
                      helperText: 'The remaining balance can be recorded later from the sale\'s detail view.',
                      helperMaxLines: 2,
                    ),
                  ),
                ],
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

// ============================================================
// _SaleDetailSheet  –  Detailed preview of one sale
// ============================================================
// Shows every field of the sale plus its full payment history.
// If a balance remains (Pending or Partial Payment), a "Record
// Payment" button lets the user log another installment — and
// the sale automatically flips to 'Paid' the moment the balance
// reaches zero (see SalesProvider.recordPayment).
// ============================================================
class _SaleDetailSheet extends StatefulWidget {
  final Sale sale;
  const _SaleDetailSheet({required this.sale});

  @override
  State<_SaleDetailSheet> createState() => _SaleDetailSheetState();
}

class _SaleDetailSheetState extends State<_SaleDetailSheet> {
  List<SalePayment> _payments = [];
  bool _isLoadingPayments = true;
  bool _isSharingReceipt = false;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final payments = await context.read<SalesProvider>().getPayments(widget.sale.id!);
    if (!mounted) return;
    setState(() {
      _payments = payments;
      _isLoadingPayments = false;
    });
  }

  // ── _shareReceipt: generate & share a one-page PDF receipt ──
  Future<void> _shareReceipt(Sale sale) async {
    setState(() => _isSharingReceipt = true);
    try {
      final profile = context.read<ProfileProvider>().profile;
      await shareSaleReceipt(sale: sale, payments: _payments, profile: profile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate receipt: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharingReceipt = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':
        return AppColors.income;
      case 'Pending':
        return AppColors.expense;
      default:
        return AppColors.warning;
    }
  }

  void _openRecordPaymentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordPaymentSheet(sale: widget.sale),
    ).then((_) {
      // Refresh this sheet's payment history after a payment is recorded,
      // and re-read the latest sale data from the provider (balance/status
      // may have just changed).
      _loadPayments();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // Re-read the freshest copy of this sale from the provider, in case
    // a payment was just recorded and its status/balance changed.
    final sales = context.watch<SalesProvider>().sales;
    final sale = sales.firstWhere((s) => s.id == widget.sale.id, orElse: () => widget.sale);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
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

              Row(
                children: [
                  Expanded(
                    child: Text(sale.itemDescription,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(sale.paymentStatus).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      sale.paymentStatus,
                      style: TextStyle(
                          fontSize: 11, color: _statusColor(sale.paymentStatus), fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _detailRow('Date', AppFormat.displayDate(sale.date)),
              if (sale.customerName != null && sale.customerName!.isNotEmpty)
                _detailRow('Customer', sale.customerName!),
              _detailRow('Quantity', '${sale.quantity}'),
              _detailRow('Unit Price', AppFormat.currency(sale.unitPrice)),
              _detailRow('Payment Method', sale.paymentMethod),
              if (sale.notes != null && sale.notes!.isNotEmpty) _detailRow('Notes', sale.notes!),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              // ── Amount summary card ────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.goldLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(AppFormat.currency(sale.totalAmount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount Paid', style: TextStyle(color: AppColors.textMuted)),
                        Text(AppFormat.currency(sale.amountPaid),
                            style: const TextStyle(color: AppColors.income, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (sale.paymentStatus != 'Paid') ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Balance Owed', style: TextStyle(color: AppColors.textMuted)),
                          Text(AppFormat.currency(sale.balance),
                              style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                    if (sale.costPrice > 0) ...[
                      const SizedBox(height: 6),
                      const Divider(height: 1),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gross Profit', style: TextStyle(color: AppColors.textMuted)),
                          Text(
                            '${AppFormat.currency(sale.grossProfit)}  (${sale.grossMarginPercent.toStringAsFixed(1)}%)',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: sale.grossProfit >= 0 ? AppColors.income : AppColors.expense),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Payment history ─────────────────────────────
              const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              if (_isLoadingPayments)
                const Center(child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ))
              else if (_payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No installment payments recorded yet.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                  ),
                )
              else
                ..._payments.map((p) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppFormat.displayDate(p.date),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(p.paymentMethod,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                          Text(AppFormat.currency(p.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.income)),
                        ],
                      ),
                    )),

              const SizedBox(height: 12),

              if (sale.paymentStatus != 'Paid')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: _openRecordPaymentSheet,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Record Payment'),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                      SizedBox(width: 6),
                      Text('Fully paid — added to Income records',
                          style: TextStyle(fontSize: 12, color: AppColors.primaryDark)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // ── Share Receipt — always available, any status ────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                  ),
                  onPressed: _isSharingReceipt ? null : () => _shareReceipt(sale),
                  icon: _isSharingReceipt
                      ? const SizedBox(
                          height: 16, width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.receipt_long_outlined),
                  label: Text(_isSharingReceipt ? 'Preparing receipt...' : 'Share Receipt'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

// ============================================================
// _RecordPaymentSheet  –  Log one installment payment
// ============================================================
class _RecordPaymentSheet extends StatefulWidget {
  final Sale sale;
  const _RecordPaymentSheet({required this.sale});

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  DateTime _selectedDate = DateTime.now();
  String? _selectedPaymentMethod;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the remaining balance — the common case is
    // "the customer just paid off what they owed"
    _amountCtrl = TextEditingController(text: widget.sale.balance.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await context.read<SalesProvider>().recordPayment(
          saleId: widget.sale.id!,
          amount: double.parse(_amountCtrl.text.trim()),
          date: AppFormat.dateToString(_selectedDate),
          paymentMethod: _selectedPaymentMethod!,
        );

    // A completed sale adds to annual turnover — refresh the VAT tracker
    if (success && mounted) {
      await context.read<VatProvider>().loadTurnover();
    }

    setState(() => _isSaving = false);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded!'), backgroundColor: AppColors.primary),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to record payment. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Pushes the sheet above the on-screen keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
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
              const Text('Record Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                'Balance owed: ${AppFormat.currency(widget.sale.balance)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Payment Date *', border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(AppFormat.displayDate(AppFormat.dateToString(_selectedDate))),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount Received *', prefixText: 'GH₵ ', border: OutlineInputBorder(),
                ),
                validator: (val) {
                  final amount = double.tryParse(val ?? '');
                  if (amount == null || amount <= 0) return 'Enter a valid amount';
                  if (amount > widget.sale.balance + 0.01) return 'Cannot exceed the balance owed';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method *', border: OutlineInputBorder()),
                items: Income.paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) => setState(() => _selectedPaymentMethod = val),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Payment'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
