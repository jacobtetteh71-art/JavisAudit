// ============================================================
// screens/inventory_screen.dart  –  Basic Stock Count
// ============================================================
// A simple per-item stock count. Items created here can be linked
// to a Sale (see sales_screen.dart) so that recording a sale
// automatically decrements stock — no separate "sell" step needed.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../utils/document_generator.dart';
import 'verify_identity_sheet.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InventoryItem> _items = [];
  bool _isLoading = true;
  bool _isAuthorized = false;
  bool _isPrintingSummary = false;

  @override
  void initState() {
    super.initState();
    // Stock figures and cost prices are sensitive — require the
    // owner's PIN/password before the screen shows anything.
    WidgetsBinding.instance.addPostFrameCallback((_) => _authorize());
  }

  Future<void> _authorize() async {
    final verified = await verifyIdentity(context, reason: 'view and manage Inventory');
    if (!mounted) return;
    if (!verified) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isAuthorized = true);
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final rows = await DatabaseHelper.instance.getInventoryItems();
    if (!mounted) return;
    setState(() {
      _items = rows.map((r) => InventoryItem.fromMap(r)).toList();
      _isLoading = false;
    });
  }

  void _openAddItemSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddInventoryItemSheet(),
    ).then((_) => _load());
  }

  Future<void> _adjustStock(InventoryItem item, int delta) async {
    await DatabaseHelper.instance.adjustInventoryStock(item.id!, delta, reason: 'Manual Adjustment');
    _load();
  }

  // ── _openSetStockDialog: "accept a new number in stock" ─────
  // A deliberate stock correction (e.g. after a physical count),
  // as opposed to the quick +/- nudges above. Requires the owner's
  // PIN/password again — right here, right before the new number
  // is accepted — even though they already unlocked the screen to
  // get this far, because this is the action that can silently
  // rewrite the books if it's wrong or done by someone else who
  // picked up an unlocked phone.
  Future<void> _openSetStockDialog(InventoryItem item) async {
    final controller = TextEditingController(text: '${item.stockQuantity}');
    String reason = 'Stock Count Correction';

    final newQuantity = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Update Stock: ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Currently ${item.stockQuantity} in stock.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'New Stock Quantity', border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: reason,
                decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
                items: const [
                  'Stock Count Correction', 'Restock', 'Damaged / Lost', 'Returned to Supplier', 'Other',
                ].map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) => setDialogState(() => reason = val ?? reason),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(controller.text.trim());
                if (qty == null || qty < 0) return;
                Navigator.pop(ctx, qty);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );

    if (newQuantity == null || newQuantity == item.stockQuantity) return;
    if (!mounted) return;

    // The authentication step this feature specifically requires,
    // right before the new number is accepted.
    final verified = await verifyIdentity(context, reason: 'update the stock count for "${item.name}"');
    if (!verified) return;

    await DatabaseHelper.instance.setInventoryStock(item.id!, newQuantity, reason: reason);
    _load();
  }

  // ── _openEditPricesSheet: cost/selling price changes ────────
  // The ONLY place these can be edited — the Sales screen shows
  // them read-only once an item is linked, on purpose, so market
  // price changes always flow through here and land in the log.
  Future<void> _openEditPricesSheet(InventoryItem item) async {
    final costCtrl = TextEditingController(text: item.costPrice.toStringAsFixed(2));
    final sellingCtrl = TextEditingController(text: item.sellingPrice.toStringAsFixed(2));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Prices: ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: costCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Cost Price', prefixText: 'GH₵ ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sellingCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Selling Price', prefixText: 'GH₵ ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            const Text(
              'Every price change is recorded in the Change Log with the date and time.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true) return;
    final newCost = double.tryParse(costCtrl.text.trim());
    final newSelling = double.tryParse(sellingCtrl.text.trim());
    if (newCost == null || newSelling == null) return;

    await DatabaseHelper.instance.updateInventoryPrices(
      item.id!,
      costPrice: newCost,
      sellingPrice: newSelling,
    );
    _load();
  }

  // ── _openChangeLog: the full stock/price audit trail ────────
  Future<void> _openChangeLog({int? itemId, String? itemName}) async {
    final rows = await DatabaseHelper.instance.getInventoryChangeLogs(itemId: itemId);
    final logs = rows.map((r) => InventoryChangeLog.fromMap(r)).toList();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
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
              Text(
                itemName != null ? 'Change Log: $itemName' : 'Change Log — All Items',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Every stock count and price change, with who — via PIN — approved it and when.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              if (logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No changes recorded yet.', style: TextStyle(color: AppColors.textMuted)),
                )
              else
                ...logs.map((log) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('${log.itemName} — ${log.fieldLabel}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                              Text(
                                '${log.changedAt.split("T").first} ${log.changedAt.split("T").last.substring(0, 5)}',
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${log.oldValue}  →  ${log.newValue}'
                            '${log.reason != null ? "   (${log.reason})" : ""}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('Remove "${item.name}" from inventory? Past sales linked to it are unaffected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.deleteInventoryItem(item.id!);
    _load();
  }

  // ── _showBestSellers: which items move fastest ─────────────
  // Helps decide what to restock first, since that's the stock
  // that turns back into cash quickest.
  Future<void> _showBestSellers() async {
    final rows = await DatabaseHelper.instance.getBestSellingItems();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
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
              const Text('Best Selling Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Ranked by units sold — restock these first to keep cash moving.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              if (rows.every((r) => (r['units_sold'] as num) == 0))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No sales linked to inventory items yet. Link a sale to an item '
                    '(on the Add Sale form) to start tracking what sells best.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              else
                ...rows.map((row) {
                  final unitsSold = (row['units_sold'] as num).toInt();
                  final revenue = (row['revenue'] as num).toDouble();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('${row['stock_quantity']} currently in stock',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$unitsSold sold', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            Text(AppFormat.currency(revenue), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  // ── _printStockSummary: shareable PDF of the whole stock list ─
  Future<void> _printStockSummary() async {
    setState(() => _isPrintingSummary = true);
    try {
      final profile = context.read<ProfileProvider>().profile;
      await printStockSummary(_items, profile: profile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate stock summary: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrintingSummary = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final lowStockCount = _items.where((i) => i.isLowStock).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            tooltip: 'Change Log',
            icon: const Icon(Icons.history),
            onPressed: _openChangeLog,
          ),
          IconButton(
            tooltip: 'Best Sellers',
            icon: const Icon(Icons.trending_up),
            onPressed: _showBestSellers,
          ),
          IconButton(
            tooltip: 'Print Stock Summary',
            icon: _isPrintingSummary
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.print_outlined),
            onPressed: _isPrintingSummary ? null : _printStockSummary,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddItemSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (lowStockCount > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.expenseLight,
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 18),
                        const SizedBox(width: 8),
                        Text('$lowStockCount item(s) low on stock',
                            style: const TextStyle(fontSize: 12, color: AppColors.expense, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                Expanded(
                  child: _items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'No inventory items yet. Add the products you stock so sales can '
                                'automatically decrement quantity on hand.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: _items.length,
                          itemBuilder: (_, index) {
                            final item = _items[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: item.isOutOfStock
                                      ? AppColors.expense
                                      : item.isLowStock
                                          ? AppColors.warning
                                          : AppColors.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit Prices',
                                        icon: const Icon(Icons.price_change_outlined, size: 18, color: AppColors.primary),
                                        onPressed: () => _openEditPricesSheet(item),
                                      ),
                                      IconButton(
                                        tooltip: 'Change Log for this item',
                                        icon: const Icon(Icons.history, size: 18, color: AppColors.textMuted),
                                        onPressed: () => _openChangeLog(itemId: item.id, itemName: item.name),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                                        onPressed: () => _deleteItem(item),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text('Cost: ${AppFormat.currency(item.costPrice)}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                      const SizedBox(width: 10),
                                      Text('Sells: ${AppFormat.currency(item.sellingPrice)}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                                            onPressed: () => _adjustStock(item, -1),
                                          ),
                                          Text('${item.stockQuantity}',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: item.isOutOfStock
                                                      ? AppColors.expense
                                                      : item.isLowStock
                                                          ? AppColors.warning
                                                          : AppColors.textPrimary)),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.add_circle_outline, size: 20),
                                            onPressed: () => _adjustStock(item, 1),
                                          ),
                                          const Text('in stock', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            tooltip: 'Set exact stock count (requires PIN)',
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.edit_note, size: 18, color: AppColors.primary),
                                            onPressed: () => _openSetStockDialog(item),
                                          ),
                                        ],
                                      ),
                                      if (item.isOutOfStock)
                                        const Text('OUT OF STOCK', style: TextStyle(fontSize: 10, color: AppColors.expense, fontWeight: FontWeight.bold))
                                      else if (item.isLowStock)
                                        const Text('LOW STOCK', style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
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
// _AddInventoryItemSheet
// ============================================================
class _AddInventoryItemSheet extends StatefulWidget {
  const _AddInventoryItemSheet();

  @override
  State<_AddInventoryItemSheet> createState() => _AddInventoryItemSheetState();
}

class _AddInventoryItemSheetState extends State<_AddInventoryItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '0');
  final _costPriceCtrl = TextEditingController();
  final _sellingPriceCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController(text: '5');
  final _skuCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isSaving = false;
  bool _showAdvanced = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _costPriceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _thresholdCtrl.dispose();
    _skuCtrl.dispose();
    _supplierCtrl.dispose();
    _unitCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final item = InventoryItem(
      name:               _nameCtrl.text.trim(),
      stockQuantity:      int.tryParse(_quantityCtrl.text.trim()) ?? 0,
      costPrice:          double.tryParse(_costPriceCtrl.text.trim()) ?? 0,
      sellingPrice:       double.tryParse(_sellingPriceCtrl.text.trim()) ?? 0,
      lowStockThreshold:  int.tryParse(_thresholdCtrl.text.trim()) ?? 5,
      sku:                _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
      supplier:           _supplierCtrl.text.trim().isEmpty ? null : _supplierCtrl.text.trim(),
      unit:               _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
      notes:              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt:          DateTime.now().toIso8601String(),
    );
    await DatabaseHelper.instance.insertInventoryItem(item.toMap());

    if (!mounted) return;
    Navigator.pop(context);
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                const Text('Add Inventory Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Item Name *', border: OutlineInputBorder()),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter an item name' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _quantityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Starting Stock Quantity *', border: OutlineInputBorder()),
                  validator: (val) => (int.tryParse(val ?? '') == null) ? 'Enter a valid whole number' : null,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Cost Price', prefixText: 'GH₵ ', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Selling Price', prefixText: 'GH₵ ', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _thresholdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Low Stock Alert Below',
                    border: OutlineInputBorder(),
                    helperText: 'You\'ll see a warning once stock drops to or below this number.',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),

                InkWell(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  child: Row(
                    children: [
                      Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more, color: AppColors.primary),
                      const SizedBox(width: 4),
                      const Text('Advanced Details (optional)',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                if (_showAdvanced) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _skuCtrl,
                    decoration: const InputDecoration(labelText: 'SKU / Item Code', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _supplierCtrl,
                    decoration: const InputDecoration(labelText: 'Supplier', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _unitCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Unit of Measure', hintText: 'e.g., pcs, kg, yards, box',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                  ),
                ],
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Item'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
