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
  final String createdAt;  // ISO 8601 timestamp, e.g. '2026-06-15T10:23:44'

  const Income({
    this.id,
    required this.date,
    required this.amount,
    required this.description,
    required this.category,
    required this.paymentMethod,
    this.notes,
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
  final String? receiptNo;   // Optional receipt or invoice number
  final String createdAt;

  const Expense({
    this.id,
    required this.date,
    required this.amount,
    required this.description,
    required this.category,
    required this.paymentMethod,
    this.receiptNo,
    required this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id:            map['id'] as int?,
      date:          map['date'] as String,
      amount:        (map['amount'] as num).toDouble(),
      description:   map['description'] as String,
      category:      map['category'] as String,
      paymentMethod: map['payment_method'] as String,
      receiptNo:     map['receipt_no'] as String?,
      createdAt:     map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date':           date,
      'amount':         amount,
      'description':    description,
      'category':       category,
      'payment_method': paymentMethod,
      'receipt_no':     receiptNo,
      'created_at':     createdAt,
    };
  }

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
  final String paymentMethod;
  final String paymentStatus;     // 'Paid' | 'Pending' | 'Partial Payment'
  final double amountPaid;        // Running total of everything paid so far
  final String? notes;
  final int? incomeId;            // FK to income table (set when status = 'Paid')
  final String createdAt;

  const Sale({
    this.id,
    required this.date,
    this.customerName,
    required this.itemDescription,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    this.amountPaid = 0,
    this.notes,
    this.incomeId,
    required this.createdAt,
  });

  // How much is still owed on this sale. Never negative, even if
  // amountPaid somehow exceeds totalAmount by a rounding fraction.
  double get balance => (totalAmount - amountPaid) < 0 ? 0 : (totalAmount - amountPaid);

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id:              map['id'] as int?,
      date:            map['date'] as String,
      customerName:    map['customer_name'] as String?,
      itemDescription: map['item_description'] as String,
      quantity:        map['quantity'] as int,
      unitPrice:       (map['unit_price'] as num).toDouble(),
      totalAmount:     (map['total_amount'] as num).toDouble(),
      paymentMethod:   map['payment_method'] as String,
      paymentStatus:   map['payment_status'] as String,
      amountPaid:      (map['amount_paid'] as num?)?.toDouble() ?? 0,
      notes:           map['notes'] as String?,
      incomeId:        map['income_id'] as int?,
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
      'payment_method':   paymentMethod,
      'payment_status':   paymentStatus,
      'amount_paid':      amountPaid,
      'notes':            notes,
      'income_id':        incomeId,
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
    required this.createdAt,
    this.updatedAt,
  });

  factory BusinessProfile.fromMap(Map<String, dynamic> map) {
    return BusinessProfile(
      id:           map['id'] as int?,
      businessName: map['business_name'] as String,
      ownerName:    map['owner_name'] as String,
      businessType: map['business_type'] as String,
      phone:        map['phone'] as String?,
      email:        map['email'] as String?,
      location:     map['location'] as String?,
      graTin:       map['gra_tin'] as String?,
      vatNumber:    map['vat_number'] as String?,
      createdAt:    map['created_at'] as String,
      updatedAt:    map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'business_name': businessName,
      'owner_name':    ownerName,
      'business_type': businessType,
      'phone':         phone,
      'email':         email,
      'location':      location,
      'gra_tin':       graTin,
      'vat_number':    vatNumber,
      'created_at':    createdAt,
      'updated_at':    updatedAt,
    };
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
