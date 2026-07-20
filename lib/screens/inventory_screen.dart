// ============================================================
// screens/inventory_screen.dart  –  Basic Stock Tracking
// ============================================================
// Lets the owner track quantity on hand, cost price, and selling
// price per item. When a Sale is linked to one of these items
// (via the "Select from Inventory" option on the Add Sale form),
// completing that sale automatically reduces quantityOnHand.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'verify_identity_sheet.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadAll();
    });
  }

  void _openAddItemSheet({InventoryItem? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddInventoryItemSheet(existing: existing),
    );
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this item?'),
        content: Text('Delete "${item.itemName}" from inventory? '
            'This does not affect any past sales already recorded.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final verified = await verifyIdentity(context, reason: 'delete this inventory item');
    if (!verified || !mounted) return;

    await context.read<InventoryProvider>().deleteItem(item.id!);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final items = provider.items;
    final lowStockCount = provider.lowStockItems.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddItemSheet(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No inventory items yet. Add items you stock so sales can '
                      'automatically reduce quantity on hand.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (lowStockCount > 0)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.expenseLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$lowStockCount item${lowStockCount == 1 ? '' : 's'} running low on stock',
                                style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ...items.map((item) => _InventoryTile(
                          item: item,
                          onEdit: () => _openAddItemSheet(existing: item),
                          onDelete: () => _deleteItem(item),
                        )),
                  ],
                ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _InventoryTile({required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.isLowStock ? AppColors.expense.withOpacity(0.4) : AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          'Cost: ${AppFormat.currency(item.costPrice)} • Sells: ${AppFormat.currency(item.sellingPrice)}',
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.quantityOnHand}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: item.isLowStock ? AppColors.expense : AppColors.primary,
                  ),
                ),
                const Text('in stock', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
              ],
            ),
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// _AddInventoryItemSheet  –  Add or edit a stock item
// ============================================================
class _AddInventoryItemSheet extends StatefulWidget {
  final InventoryItem? existing;
  const _AddInventoryItemSheet({this.existing});

  @override
  State<_AddInventoryItemSheet> createState() => _AddInventoryItemSheetState();
}

class _AddInventoryItemSheetState extends State<_AddInventoryItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _sellingCtrl;
  late final TextEditingController _reorderCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.itemName ?? '');
    _quantityCtrl = TextEditingController(text: e?.quantityOnHand.toString() ?? '0');
    _costCtrl = TextEditingController(text: e?.costPrice.toString() ?? '');
    _sellingCtrl = TextEditingController(text: e?.sellingPrice.toString() ?? '');
    _reorderCtrl = TextEditingController(text: e?.reorderLevel.toString() ?? '5');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _costCtrl.dispose();
    _sellingCtrl.dispose();
    _reorderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final item = InventoryItem(
      id: widget.existing?.id,
      itemName: _nameCtrl.text.trim(),
      quantityOnHand: int.parse(_quantityCtrl.text.trim()),
      costPrice: double.tryParse(_costCtrl.text.trim()) ?? 0,
      sellingPrice: double.tryParse(_sellingCtrl.text.trim()) ?? 0,
      reorderLevel: int.tryParse(_reorderCtrl.text.trim()) ?? 5,
      createdAt: widget.existing?.createdAt ?? DateTime.now().toIso8601String(),
    );

    final provider = context.read<InventoryProvider>();
    final success = widget.existing == null
        ? await provider.addItem(item)
        : await provider.updateItem(widget.existing!.id!, item);

    setState(() => _isSaving = false);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save item. Please try again.'), backgroundColor: Colors.red),
      );
    }
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
              Text(widget.existing == null ? 'Add Inventory Item' : 'Edit Inventory Item',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Item Name *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity on Hand *', border: OutlineInputBorder()),
                validator: (v) => (int.tryParse(v ?? '') == null) ? 'Enter a whole number' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Cost Price', prefixText: 'GH₵ ', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _sellingCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Selling Price', prefixText: 'GH₵ ', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reorderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Low Stock Alert Level',
                  border: OutlineInputBorder(),
                  helperText: 'You\'ll be flagged when stock falls to or below this number',
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
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
    );
  }
}
