// ============================================================
// screens/inventory_screen.dart  –  Basic Stock Count
// ============================================================
// A simple per-item stock count. Items created here can be linked
// to a Sale (see sales_screen.dart) so that recording a sale
// automatically decrements stock — no separate "sell" step needed.
// ============================================================

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/models.dart';
import '../utils/utils.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InventoryItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
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
    await DatabaseHelper.instance.adjustInventoryStock(item.id!, delta);
    _load();
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

  @override
  Widget build(BuildContext context) {
    final lowStockCount = _items.where((i) => i.isLowStock).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Inventory')),
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
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _costPriceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _thresholdCtrl.dispose();
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
