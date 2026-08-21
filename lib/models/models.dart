// ============================================================
// models/income_model.dart  –  Income Data Model
// ============================================================
// A model class is a Dart object that mirrors one row in the
// income table. It provides:
//  • fromMap(): convert a database row (Map) → Income object
//  • toMap(): convert an Income object → Map (for inserting)
// ============================================================

class Income {
  final int? id;           // null before first save; set by SQLite after insert
  final String date;       // Format: 'YYYY-MM-DD'
  final double amount;     // In GHS, e.g. 450.0
  final String description;
  final String category;
  final String paymentMethod;
  final String? notes;     // Optional — can be null
  // ── Optional cheque details (only meaningful when paymentMethod == 'Cheque') ──
  final String? chequeAccountNumber;
  final String? chequeAccountName;
  final String? chequeNumber;
  final String? chequeImagePath;
  final String createdAt;  // ISO 8601 timestamp, e.g. '2026-06-15T10:23:44'

  const Income({
    this.id,
    required this.date,
    required this.amount,
    required this.description,
    required this.category,
    required this.paymentMethod,
    this.notes,
    this.chequeAccountNumber,
    this.chequeAccountName,
    this.chequeNumber,
    this.chequeImagePath,
    required this.createdAt,
  });

  // Convert a database row (Map<String, dynamic>) into an Income object.
  // Called when we read rows back from SQLite.
  factory Income.fromMap(Map<String, dynamic> map) {
    return Income(
      id:            map['id'] as int?,
      date:          map['date'] as String,
      // SQLite stores numbers as either int or double; we cast safely
      amount:        (map['amount'] as num).toDouble(),
      description:   map['description'] as String,
      category:      map['category'] as String,
      paymentMethod: map['payment_method'] as String,
      notes:         map['notes'] as String?,
      chequeAccountNumber: map['cheque_account_number'] as String?,
      chequeAccountName:   map['cheque_account_name'] as String?,
      chequeNumber:        map['cheque_number'] as String?,
      chequeImagePath:     map['cheque_image_path'] as String?,
      createdAt:     map['created_at'] as String,
    );
  }

  // Convert an Income object into a Map so we can INSERT into SQLite.
  // Note: 'id' is NOT included — SQLite auto-generates it.
  Map<String, dynamic> toMap() {
    return {
      'date':           date,
      'amount':         amount,
      'description':    description,
      'category':       category,
      'payment_method': paymentMethod,
      'notes':          notes,
      'cheque_account_number': chequeAccountNumber,
      'cheque_account_name':   chequeAccountName,
      'cheque_number':         chequeNumber,
      'cheque_image_path':     chequeImagePath,
      'created_at':     createdAt,
    };
  }

  // Predefined income categories (matches the document spec)
  static const List<String> categories = [
    'Sales Revenue',
    'Service Income',
    'Rental Income',
    'Commission',
    'Loan Received',
    'Investment Income',
    'Grant / Donation',
    'Other Income',
  ];

  // Predefined payment methods (shared across income, expenses, sales)
  static const List<String> paymentMethods = [
    'Cash',
    'MTN Mobile Money',
    'Vodafone Cash',
    'AirtelTigo Money',
    'Bank Transfer',
    'Cheque',
    'POS / Card',
    'Online Payment',
  ];
}

// ============================================================
// models/expense_model.dart  –  Expense Data Model
// ============================================================

class Expense {
  final int? id;
  final String date;
  final double amount;
  final String description;
  final String category;
  final String paymentMethod;
  final String paymentStatus;   // 'Paid' | 'Pending' | 'Partial Payment'
  final double amountPaid;      // Running total of everything paid so far
  final String? receiptNo;   // Optional receipt or invoice number
  // ── Optional cheque details (only meaningful when paymentMethod == 'Cheque') ──
  final String? chequeAccountNumber;
  final String? chequeAccountName;
  final String? chequeNumber;
  final String? chequeImagePath;
  final String createdAt;
  // Optional: which specific Ghanaian tax/levy this expense is, from
  // GhanaTaxPresets — separate from `category` (which stays the
  // broad "Taxes & Levies" bucket). Null means not tagged, which is
  // fine — this is an optional refinement, not a requirement.
  final String? taxPresetKey;

  const Expense({
    this.id,
    required this.date,
    required this.amount,
    required this.description,
    required this.category,
    required this.paymentMethod,
    this.paymentStatus = 'Paid',
    this.amountPaid = 0,
    this.receiptNo,
    this.chequeAccountNumber,
    this.chequeAccountName,
    this.chequeNumber,
    this.chequeImagePath,
    required this.createdAt,
    this.taxPresetKey,
  });

  // How much of this expense is still owed. Never negative, even if
  // amountPaid somehow exceeds amount by a rounding fraction.
  double get balance => (amount - amountPaid) < 0 ? 0 : (amount - amountPaid);

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id:            map['id'] as int?,
      date:          map['date'] as String,
      amount:        (map['amount'] as num).toDouble(),
      description:   map['description'] as String,
      category:      map['category'] as String,
      paymentMethod: map['payment_method'] as String,
      paymentStatus: map['payment_status'] as String? ?? 'Paid',
      amountPaid:    (map['amount_paid'] as num?)?.toDouble() ?? 0,
      receiptNo:     map['receipt_no'] as String?,
      chequeAccountNumber: map['cheque_account_number'] as String?,
      chequeAccountName:   map['cheque_account_name'] as String?,
      chequeNumber:        map['cheque_number'] as String?,
      chequeImagePath:     map['cheque_image_path'] as String?,
      createdAt:     map['created_at'] as String,
      taxPresetKey:  map['tax_preset_key'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date':           date,
      'amount':         amount,
      'description':    description,
      'category':       category,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'amount_paid':    amountPaid,
      'receipt_no':     receiptNo,
      'cheque_account_number': chequeAccountNumber,
      'cheque_account_name':   chequeAccountName,
      'cheque_number':         chequeNumber,
      'cheque_image_path':     chequeImagePath,
      'created_at':     createdAt,
      'tax_preset_key': taxPresetKey,
    };
  }

  static const List<String> paymentStatuses = [
    'Paid',
    'Pending',
    'Partial Payment',
  ];

  // 14 expense categories from the document spec
  static const List<String> categories = [
    'Rent / Lease',
    'Salaries & Wages',
    'Utilities (Light/Water)',
    'Inventory / Stock Purchase',
    'Transport & Delivery',
    'Marketing & Advertising',
    'Equipment & Tools',
    'Taxes & Levies',
    'Maintenance & Repairs',
    'Office Supplies',
    'Loan Repayment',
    'Insurance',
    'Professional Fees',
    'Other Expenses',
  ];

  // Same payment methods list used by Income and Sales — kept as an
  // alias here so screens can call Expense.paymentMethods directly.
  static const List<String> paymentMethods = Income.paymentMethods;
}

// ============================================================
// models/sale_model.dart  –  Sale Data Model
// ============================================================

class Sale {
  final int? id;
  final String date;
  final String? customerName;     // Optional
  final String itemDescription;
  final int quantity;
  final double unitPrice;
  final double totalAmount;       // quantity × unitPrice — stored for query speed
  final double costPrice;         // Optional unit cost price — powers gross profit
  final String paymentMethod;
  final String paymentStatus;     // 'Paid' | 'Pending' | 'Partial Payment'
  final double amountPaid;        // Running total of everything paid so far
  final String? notes;
  final int? incomeId;            // FK to income table (set when status = 'Paid')
  final int? inventoryItemId;     // Optional FK to inventory_items
  // Ties several Sale rows together as ONE customer transaction
  // when more than one item was sold in a single "Record Sale" —
  // see sales_screen.dart's multi-item line entry. Null for
  // ordinary single-item sales (including everything recorded
  // before this feature existed).
  final String? saleGroupId;
  // ── Optional cheque details (only meaningful when paymentMethod == 'Cheque') ──
  final String? chequeAccountNumber;
  final String? chequeAccountName;
  final String? chequeNumber;
  final String? chequeImagePath;
  final String createdAt;

  const Sale({
    this.id,
    required this.date,
    this.customerName,
    required this.itemDescription,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    this.costPrice = 0,
    required this.paymentMethod,
    required this.paymentStatus,
    this.amountPaid = 0,
    this.notes,
    this.incomeId,
    this.inventoryItemId,
    this.saleGroupId,
    this.chequeAccountNumber,
    this.chequeAccountName,
    this.chequeNumber,
    this.chequeImagePath,
    required this.createdAt,
  });

  // How much is still owed on this sale. Never negative, even if
  // amountPaid somehow exceeds totalAmount by a rounding fraction.
  double get balance => (totalAmount - amountPaid) < 0 ? 0 : (totalAmount - amountPaid);

  // Cost of Goods Sold for this line, and what's left after it —
  // this sale's contribution to gross profit.
  double get totalCost => quantity * costPrice;
  double get grossProfit => totalAmount - totalCost;
  // Gross margin as a percentage of the sale price (0 when there's
  // no revenue, to avoid a divide-by-zero blowing up the UI).
  double get grossMarginPercent => totalAmount <= 0 ? 0 : (grossProfit / totalAmount) * 100;

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id:              map['id'] as int?,
      date:            map['date'] as String,
      customerName:    map['customer_name'] as String?,
      itemDescription: map['item_description'] as String,
      quantity:        map['quantity'] as int,
      unitPrice:       (map['unit_price'] as num).toDouble(),
      totalAmount:     (map['total_amount'] as num).toDouble(),
      costPrice:       (map['cost_price'] as num?)?.toDouble() ?? 0,
      paymentMethod:   map['payment_method'] as String,
      paymentStatus:   map['payment_status'] as String,
      amountPaid:      (map['amount_paid'] as num?)?.toDouble() ?? 0,
      notes:           map['notes'] as String?,
      incomeId:        map['income_id'] as int?,
      inventoryItemId: map['inventory_item_id'] as int?,
      saleGroupId:     map['sale_group_id'] as String?,
      chequeAccountNumber: map['cheque_account_number'] as String?,
      chequeAccountName:   map['cheque_account_name'] as String?,
      chequeNumber:        map['cheque_number'] as String?,
      chequeImagePath:     map['cheque_image_path'] as String?,
      createdAt:       map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date':             date,
      'customer_name':    customerName,
      'item_description': itemDescription,
      'quantity':         quantity,
      'unit_price':       unitPrice,
      'total_amount':     totalAmount,
      'cost_price':       costPrice,
      'payment_method':   paymentMethod,
      'payment_status':   paymentStatus,
      'amount_paid':      amountPaid,
      'notes':            notes,
      'income_id':        incomeId,
      'inventory_item_id': inventoryItemId,
      'sale_group_id':    saleGroupId,
      'cheque_account_number': chequeAccountNumber,
      'cheque_account_name':   chequeAccountName,
      'cheque_number':         chequeNumber,
      'cheque_image_path':     chequeImagePath,
      'created_at':       createdAt,
    };
  }

  static const List<String> paymentStatuses = [
    'Paid',
    'Pending',
    'Partial Payment',
  ];
}

// ============================================================
// models/sale_payment_model.dart  –  Sale Payment History
// ============================================================
// One row per installment payment recorded against a Sale that
// was Pending or Partial Payment. Lets the app show a full
// payment history and know exactly how much is still owed.

class SalePayment {
  final int? id;
  final int saleId;
  final double amount;
  final String paymentMethod;
  final String date;
  final String createdAt;

  const SalePayment({
    this.id,
    required this.saleId,
    required this.amount,
    required this.paymentMethod,
    required this.date,
    required this.createdAt,
  });

  factory SalePayment.fromMap(Map<String, dynamic> map) {
    return SalePayment(
      id:            map['id'] as int?,
      saleId:        map['sale_id'] as int,
      amount:        (map['amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      date:          map['date'] as String,
      createdAt:     map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sale_id':        saleId,
      'amount':         amount,
      'payment_method': paymentMethod,
      'date':           date,
      'created_at':     createdAt,
    };
  }
}

// ============================================================
// models/expense_payment_model.dart  –  Expense Payment History
// ============================================================
// One row per installment payment recorded against an Expense that
// was Pending or Partial Payment. Mirrors SalePayment exactly.

class ExpensePayment {
  final int? id;
  final int expenseId;
  final double amount;
  final String paymentMethod;
  final String date;
  final String createdAt;

  const ExpensePayment({
    this.id,
    required this.expenseId,
    required this.amount,
    required this.paymentMethod,
    required this.date,
    required this.createdAt,
  });

  factory ExpensePayment.fromMap(Map<String, dynamic> map) {
    return ExpensePayment(
      id:            map['id'] as int?,
      expenseId:     map['expense_id'] as int,
      amount:        (map['amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      date:          map['date'] as String,
      createdAt:     map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'expense_id':     expenseId,
      'amount':         amount,
      'payment_method': paymentMethod,
      'date':           date,
      'created_at':     createdAt,
    };
  }
}

// ============================================================
// models/recurring_expense_template_model.dart
// ============================================================
// A saved expense pattern — rent, salaries, utilities — that gets
// logged again with one tap instead of retyping every month.

class RecurringExpenseTemplate {
  final int? id;
  final String description;
  final String category;
  final double amount;
  final String paymentMethod;
  final String createdAt;

  const RecurringExpenseTemplate({
    this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.createdAt,
  });

  factory RecurringExpenseTemplate.fromMap(Map<String, dynamic> map) {
    return RecurringExpenseTemplate(
      id:            map['id'] as int?,
      description:   map['description'] as String,
      category:      map['category'] as String,
      amount:        (map['amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      createdAt:     map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description':    description,
      'category':       category,
      'amount':         amount,
      'payment_method': paymentMethod,
      'created_at':     createdAt,
    };
  }
}

// ============================================================
// models/inventory_item_model.dart
// ============================================================
// A basic stock-count record. Optionally linked from Sales via
// Sale — selling an item decrements stockQuantity automatically.

class InventoryItem {
  final int? id;
  final String name;
  final int stockQuantity;
  final double costPrice;
  final double sellingPrice;
  final int lowStockThreshold;
  // ── Advanced (optional) details ─────────────────────────
  final String? sku;
  final String? supplier;
  final String? unit;
  final String? notes;
  final String createdAt;

  const InventoryItem({
    this.id,
    required this.name,
    required this.stockQuantity,
    this.costPrice = 0,
    this.sellingPrice = 0,
    this.lowStockThreshold = 5,
    this.sku,
    this.supplier,
    this.unit,
    this.notes,
    required this.createdAt,
  });

  bool get isLowStock => stockQuantity <= lowStockThreshold;
  bool get isOutOfStock => stockQuantity <= 0;
  double get stockValue => stockQuantity * costPrice;

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id:                 map['id'] as int?,
      name:               map['name'] as String,
      stockQuantity:      map['stock_quantity'] as int,
      costPrice:          (map['cost_price'] as num?)?.toDouble() ?? 0,
      sellingPrice:       (map['selling_price'] as num?)?.toDouble() ?? 0,
      lowStockThreshold:  map['low_stock_threshold'] as int? ?? 5,
      sku:                map['sku'] as String?,
      supplier:           map['supplier'] as String?,
      unit:               map['unit'] as String?,
      notes:              map['notes'] as String?,
      createdAt:          map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name':                name,
      'stock_quantity':      stockQuantity,
      'cost_price':          costPrice,
      'selling_price':       sellingPrice,
      'low_stock_threshold': lowStockThreshold,
      'sku':                 sku,
      'supplier':            supplier,
      'unit':                unit,
      'notes':               notes,
      'created_at':          createdAt,
    };
  }
}

// ============================================================
// models/customer_model.dart  –  Customer Contact Directory
// ============================================================
// Kept separate from Sales so contact details survive independent
// of how a customer's name happens to be typed on any one sale.

class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String createdAt;

  const Customer({
    this.id,
    required this.name,
    this.phone,
    this.email,
    required this.createdAt,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id:        map['id'] as int?,
      name:      map['name'] as String,
      phone:     map['phone'] as String?,
      email:     map['email'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name':       name,
      'phone':      phone,
      'email':      email,
      'created_at': createdAt,
    };
  }
}

// ============================================================
// models/profile_model.dart  –  Business Profile Model
// ============================================================

class BusinessProfile {
  final int? id;
  final String businessName;
  final String ownerName;
  final String businessType;
  final String? phone;
  final String? email;
  final String? location;
  final String? graTin;
  final String? vatNumber;
  final String? profileImagePath; // Local file path to the chosen profile picture
  final String createdAt;
  final String? updatedAt;

  const BusinessProfile({
    this.id,
    required this.businessName,
    required this.ownerName,
    required this.businessType,
    this.phone,
    this.email,
    this.location,
    this.graTin,
    this.vatNumber,
    this.profileImagePath,
    required this.createdAt,
    this.updatedAt,
  });

  factory BusinessProfile.fromMap(Map<String, dynamic> map) {
    return BusinessProfile(
      id:               map['id'] as int?,
      businessName:     map['business_name'] as String,
      ownerName:        map['owner_name'] as String,
      businessType:     map['business_type'] as String,
      phone:            map['phone'] as String?,
      email:            map['email'] as String?,
      location:         map['location'] as String?,
      graTin:           map['gra_tin'] as String?,
      vatNumber:        map['vat_number'] as String?,
      profileImagePath: map['profile_image_path'] as String?,
      createdAt:        map['created_at'] as String,
      updatedAt:        map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'business_name':      businessName,
      'owner_name':         ownerName,
      'business_type':      businessType,
      'phone':              phone,
      'email':              email,
      'location':           location,
      'gra_tin':            graTin,
      'vat_number':         vatNumber,
      'profile_image_path': profileImagePath,
      'created_at':         createdAt,
      'updated_at':         updatedAt,
    };
  }

  // ── copyWith: used when updating JUST the profile picture,
  // without needing to reconstruct every other field manually
  BusinessProfile copyWith({String? profileImagePath}) {
    return BusinessProfile(
      id: id,
      businessName: businessName,
      ownerName: ownerName,
      businessType: businessType,
      phone: phone,
      email: email,
      location: location,
      graTin: graTin,
      vatNumber: vatNumber,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // 12 business type options from the document spec
  static const List<String> businessTypes = [
    'Retail Shop',
    'Restaurant / Food Business',
    'Services Provider',
    'Manufacturing',
    'Wholesale / Distribution',
    'Agriculture',
    'Technology / IT',
    'Transport / Logistics',
    'Healthcare',
    'Education',
    'Construction',
    'Other',
  ];
}

// ============================================================
// models/inventory_change_log_model.dart  –  Stock & Price Audit Trail
// ============================================================
// One row every time an inventory item's stock quantity, cost
// price, or selling price changes — who changed what, from what
// to what, and when. Powers the "Change Log" view on the
// Inventory screen so nothing moves silently.
// ============================================================

class InventoryChangeLog {
  final int? id;
  final int inventoryItemId;
  final String itemName;      // Snapshot of the name at the time of change,
                               // so the log still reads clearly even if the
                               // item is later renamed or deleted.
  final String fieldChanged;  // 'stock_quantity' | 'cost_price' | 'selling_price'
  final String oldValue;
  final String newValue;
  final String? reason;       // e.g. 'Restock', 'Stock Count Correction', 'Sale', 'Price Update'
  final String changedAt;     // ISO 8601 timestamp

  const InventoryChangeLog({
    this.id,
    required this.inventoryItemId,
    required this.itemName,
    required this.fieldChanged,
    required this.oldValue,
    required this.newValue,
    this.reason,
    required this.changedAt,
  });

  // Human-friendly label for the field that changed
  String get fieldLabel {
    switch (fieldChanged) {
      case 'stock_quantity':
        return 'Stock Quantity';
      case 'cost_price':
        return 'Cost Price';
      case 'selling_price':
        return 'Selling Price';
      default:
        return fieldChanged;
    }
  }

  factory InventoryChangeLog.fromMap(Map<String, dynamic> map) {
    return InventoryChangeLog(
      id:              map['id'] as int?,
      inventoryItemId: map['inventory_item_id'] as int,
      itemName:        map['item_name'] as String,
      fieldChanged:    map['field_changed'] as String,
      oldValue:        map['old_value'] as String,
      newValue:        map['new_value'] as String,
      reason:          map['reason'] as String?,
      changedAt:       map['changed_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'inventory_item_id': inventoryItemId,
      'item_name':         itemName,
      'field_changed':     fieldChanged,
      'old_value':         oldValue,
      'new_value':         newValue,
      'reason':            reason,
      'changed_at':        changedAt,
    };
  }
}
