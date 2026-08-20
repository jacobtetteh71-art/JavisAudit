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
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../utils/receipt_generator.dart';
import '../widgets/cheque_details_fields.dart';
import 'sales_performance_screen.dart';
import 'verify_identity_sheet.dart';

class SalesScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  const SalesScreen({super.key, this.onMenuTap});

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

  // Groups a flat sales list into transactions — several Sale rows
  // sharing a saleGroupId (a multi-item sale) collapse into one
  // list entry; everything else (the vast majority, including
  // every sale recorded before this feature existed) stays as its
  // own single-item entry.
  List<List<Sale>> _groupSales(List<Sale> sales) {
    final Map<String, List<Sale>> groups = {};
    final List<String> order = [];
    for (final s in sales) {
      final key = s.saleGroupId ?? 'single-${s.id}';
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(s);
    }
    return order.map((k) => groups[k]!).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesProvider>();
    final sales = provider.sales;
    final totalSales = sales.fold<double>(0, (sum, s) => sum + s.totalAmount);
    final groupedSales = _groupSales(sales);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: widget.onMenuTap,
        ),
        title: const Text('Sales'),
        actions: [
          IconButton(
            tooltip: 'Sales Performance',
            icon: const Icon(Icons.insert_chart_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalesPerformanceScreen()),
            ),
          ),
        ],
      ),
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
                          itemCount: groupedSales.length,
                          itemBuilder: (_, index) {
                            final group = groupedSales[index];
                            return group.length > 1
                                ? _SaleGroupTile(sales: group)
                                : _SaleListTile(sale: group.first);
                          },
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

// ============================================================
// _SaleGroupTile / _SaleGroupDetailSheet  –  Multi-item sale
// ============================================================
// Several Sale rows recorded together under one saleGroupId show
// up as ONE card in the list — tapping it drills into every line
// item, each of which still opens the ordinary _SaleDetailSheet
// (record payment, delete, single-item receipt all work exactly
// as before) so there's no separate logic to keep in sync.
// ============================================================
class _SaleGroupTile extends StatelessWidget {
  final List<Sale> sales;
  const _SaleGroupTile({required this.sales});

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

  @override
  Widget build(BuildContext context) {
    final first = sales.first;
    final grandTotal = sales.fold<double>(0, (s, sale) => s + sale.totalAmount);
    final overallStatus = sales.every((s) => s.paymentStatus == 'Paid')
        ? 'Paid'
        : (sales.any((s) => s.paymentStatus == 'Partial Payment' || s.amountPaid > 0) ? 'Partial Payment' : 'Pending');

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SaleGroupDetailSheet(sales: sales),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 16, color: AppColors.gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${sales.length} items sold',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(overallStatus).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(overallStatus,
                      style: TextStyle(fontSize: 10, color: _statusColor(overallStatus), fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (first.customerName != null && first.customerName!.isNotEmpty)
              Text('Customer: ${first.customerName}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            Text(
              sales.map((s) => s.itemDescription).join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            Text(AppFormat.displayDate(first.date), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(AppFormat.currency(grandTotal),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.gold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleGroupDetailSheet extends StatefulWidget {
  final List<Sale> sales;
  const _SaleGroupDetailSheet({required this.sales});

  @override
  State<_SaleGroupDetailSheet> createState() => _SaleGroupDetailSheetState();
}

class _SaleGroupDetailSheetState extends State<_SaleGroupDetailSheet> {
  bool _isSharingReceipt = false;

  Future<void> _shareCombinedReceipt() async {
    setState(() => _isSharingReceipt = true);
    try {
      final profile = context.read<ProfileProvider>().profile;
      await shareGroupedSaleReceipt(profile: profile, sales: widget.sales);
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

  @override
  Widget build(BuildContext context) {
    final sales = widget.sales;
    final first = sales.first;
    final grandTotal = sales.fold<double>(0, (s, sale) => s + sale.totalAmount);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
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
            Text('${sales.length}-Item Sale', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (first.customerName != null && first.customerName!.isNotEmpty)
              Text('Customer: ${first.customerName}', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            Text(AppFormat.displayDate(first.date), style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            const Text('Tap an item to view, pay, or delete it individually.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            ...sales.map((sale) => InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _SaleDetailSheet(sale: sale),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sale.itemDescription, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('${sale.quantity} × ${AppFormat.currency(sale.unitPrice)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        Text(AppFormat.currency(sale.totalAmount),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold)),
                        const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(AppFormat.currency(grandTotal),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.gold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSharingReceipt ? null : _shareCombinedReceipt,
                icon: _isSharingReceipt
                    ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(_isSharingReceipt ? 'Preparing…' : 'Share Combined Receipt'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// One row of "what was sold" — a sale can now have several of
// these under one customer/date/payment (feature: multiple items
// in one sale). Each line keeps its own controllers and its own
// linked inventory item (if any).
class _SaleLineItemControllers {
  final itemCtrl = TextEditingController();
  final quantityCtrl = TextEditingController(text: '1');
  final unitPriceCtrl = TextEditingController();
  final costPriceCtrl = TextEditingController();
  InventoryItem? selectedInventoryItem;

  double get total => (int.tryParse(quantityCtrl.text) ?? 0) * (double.tryParse(unitPriceCtrl.text) ?? 0);
  double get profit => total - (int.tryParse(quantityCtrl.text) ?? 0) * (double.tryParse(costPriceCtrl.text) ?? 0);

  void dispose() {
    itemCtrl.dispose();
    quantityCtrl.dispose();
    unitPriceCtrl.dispose();
    costPriceCtrl.dispose();
  }
}

class _AddSaleSheetState extends State<_AddSaleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _customerCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _amountPaidCtrl = TextEditingController(); // Only shown for Partial Payment

  // One or more items being sold in this single transaction.
  final List<_SaleLineItemControllers> _lines = [_SaleLineItemControllers()];

  DateTime _selectedDate = DateTime.now();
  String? _selectedPaymentMethod;
  String _selectedStatus = 'Paid'; // Default to Paid
  bool _isSaving = false;
  final _chequeDetails = ChequeDetailsController();
  List<InventoryItem> _inventoryItems = [];
  List<String> _customerNames = [];
  bool _autocompleteListenerAdded = false;

  // How far back a sale can be dated without special handling.
  // Anything older than this is rejected outright; anything from
  // yesterday up to this limit still requires re-authentication
  // (see _pickDate).
  static const int _maxBackdateDays = 3;

  Future<void> _loadInventoryItems() async {
    final rows = await DatabaseHelper.instance.getInventoryItems();
    if (!mounted) return;
    setState(() => _inventoryItems = rows.map((r) => InventoryItem.fromMap(r)).toList());
  }

  Future<void> _loadCustomerNames() async {
    final ledger = await DatabaseHelper.instance.getCustomerLedger();
    final customers = await DatabaseHelper.instance.getCustomers();
    if (!mounted) return;
    final names = <String>{
      ...ledger.map((r) => r['customer_name'] as String),
      ...customers.map((c) => c['name'] as String),
    };
    setState(() => _customerNames = names.toList()..sort());
  }

  // The live-calculated grand total across every line item
  double get _computedTotal => _lines.fold<double>(0, (s, l) => s + l.total);
  double get _computedProfit => _lines.fold<double>(0, (s, l) => s + l.profit);

  void _addLine() {
    final line = _SaleLineItemControllers();
    line.itemCtrl.addListener(() => setState(() {}));
    line.quantityCtrl.addListener(() => setState(() {}));
    line.unitPriceCtrl.addListener(() => setState(() {}));
    line.costPriceCtrl.addListener(() => setState(() {}));
    setState(() => _lines.add(line));
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  @override
  void initState() {
    super.initState();
    // Listen to changes on the first (default) line so the total
    // updates live — _addLine() wires up listeners for any more.
    _lines.first.itemCtrl.addListener(() => setState(() {}));
    _lines.first.quantityCtrl.addListener(() => setState(() {}));
    _lines.first.unitPriceCtrl.addListener(() => setState(() {}));
    _lines.first.costPriceCtrl.addListener(() => setState(() {}));
    _loadInventoryItems();
    _loadCustomerNames();
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _notesCtrl.dispose();
    _amountPaidCtrl.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    _chequeDetails.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final earliestAllowed = DateTime.now().subtract(const Duration(days: _maxBackdateDays));
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      // Sales cannot be backdated more than _maxBackdateDays days —
      // the date picker itself won't offer anything earlier.
      firstDate: earliestAllowed,
      lastDate: DateTime.now(),
    );
    if (picked == null) return;

    final isToday = AppFormat.dateToString(picked) == AppFormat.dateToString(DateTime.now());
    if (!isToday) {
      // Backdating at all — even by a day — requires re-authentication.
      if (!mounted) return;
      final verified = await verifyIdentity(context, reason: 'record a sale for a past date');
      if (!verified) return; // Leave the date exactly as it was
    }

    setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPaymentMethod == null) {
      _showError('Please select a payment method.');
      return;
    }
    if (_lines.any((l) => l.itemCtrl.text.trim().length < 2)) {
      _showError('Enter the item or service sold for every line.');
      return;
    }

    final grandTotal = _computedTotal;

    // For a Partial Payment, an initial amount paid so far is required
    double startingAmountPaid = 0;
    if (_selectedStatus == 'Partial Payment') {
      final entered = double.tryParse(_amountPaidCtrl.text.trim());
      if (entered == null || entered <= 0) {
        _showError('Enter how much has been paid so far.');
        return;
      }
      if (entered >= grandTotal) {
        _showError('That covers the full amount — please choose "Paid" instead.');
        return;
      }
      startingAmountPaid = entered;
    }

    setState(() => _isSaving = true);

    // Several items sold together share one saleGroupId, so the
    // Sales list and receipt can present them as one transaction.
    // A single-item sale (the common case) stays untagged, exactly
    // as every sale before this feature existed.
    final saleGroupId = _lines.length > 1 ? const Uuid().v4() : null;

    bool allSucceeded = true;
    double amountAllocated = 0;
    final savedSales = <Sale>[];

    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final lineTotal = line.total;

      // Distribute a Partial Payment across lines proportionally
      // by each line's share of the grand total. The LAST line
      // absorbs any rounding remainder so the sum matches exactly.
      double lineAmountPaid;
      if (_selectedStatus == 'Paid') {
        lineAmountPaid = lineTotal; // resolved by SalesProvider.addSale
      } else if (_selectedStatus == 'Partial Payment') {
        lineAmountPaid = (i == _lines.length - 1)
            ? (startingAmountPaid - amountAllocated)
            : (grandTotal == 0 ? 0 : startingAmountPaid * (lineTotal / grandTotal));
        amountAllocated += lineAmountPaid;
      } else {
        lineAmountPaid = 0;
      }

      final sale = Sale(
        date:             AppFormat.dateToString(_selectedDate),
        customerName:     _customerCtrl.text.trim().isEmpty ? null : _customerCtrl.text.trim(),
        itemDescription:  line.itemCtrl.text.trim(),
        quantity:         int.parse(line.quantityCtrl.text.trim()),
        unitPrice:        double.parse(line.unitPriceCtrl.text.trim()),
        totalAmount:      lineTotal,
        costPrice:        double.tryParse(line.costPriceCtrl.text.trim()) ?? 0,
        paymentMethod:    _selectedPaymentMethod!,
        paymentStatus:    _selectedStatus,
        amountPaid:       lineAmountPaid,
        notes:            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        inventoryItemId:  line.selectedInventoryItem?.id,
        saleGroupId:      saleGroupId,
        chequeAccountNumber: _chequeDetails.toMap()['cheque_account_number'],
        chequeAccountName:   _chequeDetails.toMap()['cheque_account_name'],
        chequeNumber:        _chequeDetails.toMap()['cheque_number'],
        chequeImagePath:     _chequeDetails.imagePath,
        createdAt:        DateTime.now().toIso8601String(),
      );

      // SalesProvider.addSale() automatically creates a matching
      // income entry if paymentStatus == 'Paid' — see providers.dart
      final success = await context.read<SalesProvider>().addSale(sale);
      if (!success) {
        allSucceeded = false;
        continue;
      }
      savedSales.add(sale);

      // If this line was linked to an inventory item, reduce stock
      // by the quantity sold — logged automatically as a 'Sale'.
      if (line.selectedInventoryItem != null) {
        await DatabaseHelper.instance.adjustInventoryStock(
          line.selectedInventoryItem!.id!,
          -int.parse(line.quantityCtrl.text.trim()),
          reason: 'Sale',
        );
      }
    }

    // Refresh VAT tracker once, since a Paid sale adds to annual turnover
    if (allSucceeded && mounted) {
      await context.read<VatProvider>().loadTurnover();
    }

    setState(() => _isSaving = false);
    if (!mounted) return;

    if (allSucceeded) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_lines.length > 1
              ? 'Sale recorded successfully (${_lines.length} items)!'
              : 'Sale recorded successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      _showError('Some items could not be saved. Please check and try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  // ── One line item's fields ───────────────────────────────────
  // Deliberately compact: with several product slots stacked on
  // screen at once (the whole point of "Add Another Item"), every
  // extra line of helper text or an extra field-row here gets
  // multiplied by however many items are in the sale. Quantity,
  // Unit Price, and Unit Cost Price now share one row instead of
  // two, and helper text is trimmed to a single line — together
  // that's roughly two fewer field-heights per slot than before,
  // without dropping any functionality (inventory linking, the
  // locked cost price display, live line totals — all still here).
  Widget _buildLineItem(int index) {
    final line = _lines[index];
    final isLinked = line.selectedInventoryItem != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Item ${index + 1}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
              ),
              Text('Line total: ${AppFormat.currency(line.total)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              if (_lines.length > 1)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(left: 4),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, size: 18, color: AppColors.expense),
                  onPressed: () => _removeLine(index),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_inventoryItems.isNotEmpty) ...[
            DropdownButtonFormField<InventoryItem>(
              value: line.selectedInventoryItem,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Link to Inventory Item (optional)', border: OutlineInputBorder(),
                helperText: 'Auto-fills item, price & cost.',
                isDense: true,
              ),
              items: _inventoryItems
                  .map((i) => DropdownMenuItem(
                        value: i,
                        child: Text('${i.name} (${i.stockQuantity} in stock)', overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (item) {
                setState(() {
                  line.selectedInventoryItem = item;
                  if (item != null) {
                    line.itemCtrl.text = item.name;
                    if (item.sellingPrice > 0) line.unitPriceCtrl.text = item.sellingPrice.toStringAsFixed(2);
                    if (item.costPrice > 0) line.costPriceCtrl.text = item.costPrice.toStringAsFixed(2);
                  }
                });
              },
            ),
            const SizedBox(height: 8),
          ],

          TextFormField(
            controller: line.itemCtrl,
            decoration: const InputDecoration(
              labelText: 'Item / Service *', hintText: 'e.g., 2 yards of Ankara fabric',
              border: OutlineInputBorder(), isDense: true,
            ),
            validator: (val) {
              if (val == null || val.trim().length < 2) return 'Enter the item or service sold';
              return null;
            },
          ),
          const SizedBox(height: 8),

          // Quantity, Unit Price, and Unit Cost Price share one row
          // — this used to be two stacked rows.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.quantityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Qty *', border: OutlineInputBorder(), isDense: true),
                  validator: (val) {
                    final q = int.tryParse(val ?? '');
                    if (q == null || q <= 0) return '>0';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: line.unitPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Price *', prefixText: 'GH₵', border: OutlineInputBorder(), isDense: true),
                  validator: (val) {
                    final p = double.tryParse(val ?? '');
                    if (p == null || p <= 0) return '>0';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Unit cost price: locked once an inventory item is
              // linked — the only place to change it is Inventory ▸
              // Edit Prices, so every price change is captured in
              // one audit trail.
              Expanded(
                child: isLinked
                    ? InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Cost', border: OutlineInputBorder(), isDense: true,
                          filled: true, fillColor: Color(0xFFF0F0F0),
                        ),
                        child: Text(
                          AppFormat.currency(double.tryParse(line.costPriceCtrl.text) ?? 0),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : TextFormField(
                        controller: line.costPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Cost', prefixText: 'GH₵', border: OutlineInputBorder(), isDense: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return null;
                          final p = double.tryParse(val);
                          if (p == null || p < 0) return 'Invalid';
                          return null;
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
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
                      helperText: 'Dates more than 3 days old require sign-in to confirm.',
                      helperMaxLines: 2,
                    ),
                    child: Text(AppFormat.displayDate(AppFormat.dateToString(_selectedDate))),
                  ),
                ),
                const SizedBox(height: 12),

                Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.trim().isEmpty) return const Iterable<String>.empty();
                    return _customerNames.where(
                      (name) => name.toLowerCase().contains(textEditingValue.text.toLowerCase()),
                    );
                  },
                  onSelected: (selection) => _customerCtrl.text = selection,
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    if (!_autocompleteListenerAdded) {
                      // Keep the Autocomplete's own field in sync with
                      // _customerCtrl, which is what _submit() reads from
                      controller.addListener(() => _customerCtrl.text = controller.text);
                      _autocompleteListenerAdded = true;
                    }
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name (optional)', border: OutlineInputBorder(),
                        helperText: 'Start typing to find an existing customer.',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                const Text('Items Sold', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (int i = 0; i < _lines.length; i++) _buildLineItem(i),

                OutlinedButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Another Item'),
                ),
                const SizedBox(height: 16),

                // ── Live-calculated grand total display ──────────
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
                          Text(_lines.length > 1 ? 'Grand Total (${_lines.length} items)' : 'Total Amount',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            AppFormat.currency(_computedTotal),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.gold),
                          ),
                        ],
                      ),
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
                      helperText: 'Split automatically across items sold; the rest can be recorded later.',
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSharingReceipt ? null : () => _shareReceipt(sale),
                  icon: _isSharingReceipt
                      ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.receipt_long_outlined, size: 18),
                  label: Text(_isSharingReceipt ? 'Preparing…' : 'Share Receipt'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.expense),
                  onPressed: () => _confirmAndDelete(sale),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete This Sale'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  bool _isSharingReceipt = false;

  Future<void> _confirmAndDelete(Sale sale) async {
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
    if (!confirmedIntent) return;
    if (!mounted) return;

    final verified = await verifyIdentity(context, reason: 'delete this sale');
    if (!verified) return;
    if (!mounted) return;

    await context.read<SalesProvider>().deleteSale(sale.id!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _shareReceipt(Sale sale) async {
    setState(() => _isSharingReceipt = true);
    try {
      final profile = context.read<ProfileProvider>().profile;
      await shareSaleReceipt(profile: profile, sale: sale);
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
