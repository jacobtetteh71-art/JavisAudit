// ============================================================
// providers/inventory_provider.dart  –  Stock Item State Manager
// ============================================================
// Basic inventory tracking. Sales can optionally link to one of
// these items — completing that sale then automatically reduces
// quantityOnHand (handled in SalesProvider, not here).

import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class InventoryProvider extends ChangeNotifier {
  List<InventoryItem> _items = [];
  bool _isLoading = false;

  List<InventoryItem> get items     => _items;
  bool                 get isLoading => _isLoading;

  // Items at or below their reorder level — used for a "low stock"
  // badge/warning elsewhere in the app (e.g. Dashboard)
  List<InventoryItem> get lowStockItems => _items.where((i) => i.isLowStock).toList();

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    final rows = await DatabaseHelper.instance.getAllInventoryItems();
    _items = rows.map((row) => InventoryItem.fromMap(row)).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addItem(InventoryItem item) async {
    try {
      await DatabaseHelper.instance.insertInventoryItem(item.toMap());
      await loadAll();
      return true;
    } catch (e) {
      debugPrint('Error adding inventory item: $e');
      return false;
    }
  }

  Future<bool> updateItem(int id, InventoryItem item) async {
    try {
      final map = item.toMap();
      map['updated_at'] = DateTime.now().toIso8601String();
      await DatabaseHelper.instance.updateInventoryItem(id, map);
      await loadAll();
      return true;
    } catch (e) {
      debugPrint('Error updating inventory item: $e');
      return false;
    }
  }

  Future<bool> deleteItem(int id) async {
    try {
      await DatabaseHelper.instance.deleteInventoryItem(id);
      _items.removeWhere((i) => i.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting inventory item: $e');
      return false;
    }
  }
}
