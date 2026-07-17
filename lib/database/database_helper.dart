// ============================================================
// database/database_helper.dart  –  SQLite Database Layer
// ============================================================
// This file is the ONLY place that talks directly to the
// SQLite database. Everything else in the app calls methods
// here — no raw SQL anywhere else.
//
// Pattern used: Singleton
//   DatabaseHelper.instance gives the same object everywhere,
//   ensuring only one database connection is ever open.
// ============================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  // ── Singleton setup ────────────────────────────────────────
  // Private constructor — prevents "new DatabaseHelper()" from
  // being called from outside this file
  DatabaseHelper._privateConstructor();

  // The single shared instance of this class
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // The actual database object — nullable until first accessed
  static Database? _database;

  // ── The database getter ────────────────────────────────────
  // Returns the existing database if it's already open,
  // otherwise creates/opens it for the first time.
  // The 'async' keyword means this runs without freezing the UI.
  Future<Database> get database async {
    // If we already have an open database, return it immediately
    if (_database != null) return _database!;

    // Otherwise, open/create the database
    _database = await _initDatabase();
    return _database!;
  }

  // ── _initDatabase: open or create the SQLite file ──────────
  Future<Database> _initDatabase() async {
    // getDatabasesPath() returns the correct directory on
    // Android (usually /data/data/<package>/databases/)
    final dbPath = await getDatabasesPath();

    // p.join builds the full path:
    // e.g., /data/data/com.javisaudit/databases/javisaudit.db
    final path = p.join(dbPath, 'javisaudit.db');

    // openDatabase creates the file if it doesn't exist,
    // or opens it if it does.
    // version: 1 — if we ever change the schema, we increment
    // this and handle the migration in onUpgrade
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables, // Called only when db is brand new
    );
  }

  // ── _createTables: define all five tables ─────────────────
  // This runs once — the very first time the app is installed
  // and the database file does not yet exist.
  Future<void> _createTables(Database db, int version) async {
    // ── Table 1: business_profile ──────────────────────────
    // Singleton table: only ever has ONE row (id = 1).
    // Stores the business identity used in reports and PDFs.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS business_profile (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        business_name TEXT    NOT NULL,
        owner_name    TEXT    NOT NULL,
        business_type TEXT    NOT NULL,
        phone         TEXT,
        email         TEXT,
        location      TEXT,
        gra_tin       TEXT,
        vat_number    TEXT,
        created_at    TEXT    NOT NULL,
        updated_at    TEXT
      )
    ''');

    // ── Table 2: income ────────────────────────────────────
    // Every money-in entry. The CHECK constraint prevents
    // negative amounts from being stored.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS income (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        date           TEXT    NOT NULL,
        amount         REAL    NOT NULL CHECK(amount > 0),
        description    TEXT    NOT NULL,
        category       TEXT    NOT NULL,
        payment_method TEXT    NOT NULL,
        notes          TEXT,
        created_at     TEXT    NOT NULL
      )
    ''');

    // ── Table 3: expenses ──────────────────────────────────
    // Every money-out entry.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        date           TEXT    NOT NULL,
        amount         REAL    NOT NULL CHECK(amount > 0),
        description    TEXT    NOT NULL,
        category       TEXT    NOT NULL,
        payment_method TEXT    NOT NULL,
        receipt_no     TEXT,
        created_at     TEXT    NOT NULL
      )
    ''');

    // ── Table 4: sales ────────────────────────────────────
    // Itemised sale records. When payment_status = 'Paid',
    // the app also inserts a matching row into the income
    // table so the VAT cumulative total stays accurate.
    // income_id links back to that auto-created income entry.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        date             TEXT    NOT NULL,
        customer_name    TEXT,
        item_description TEXT    NOT NULL,
        quantity         INTEGER NOT NULL CHECK(quantity > 0),
        unit_price       REAL    NOT NULL CHECK(unit_price > 0),
        total_amount     REAL    NOT NULL,
        payment_method   TEXT    NOT NULL,
        payment_status   TEXT    NOT NULL DEFAULT 'Paid',
        notes            TEXT,
        income_id        INTEGER,
        created_at       TEXT    NOT NULL,
        FOREIGN KEY (income_id) REFERENCES income(id)
      )
    ''');

    // ── Table 5: settings ────────────────────────────────
    // App-level settings. Always has one row (id = 1).
    // vat_threshold stores the current GRA limit (GHS 750,000)
    // so we can update it in future without a code change.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        currency_symbol TEXT    DEFAULT 'GH₵',
        vat_threshold   REAL    DEFAULT 750000.0,
        updated_at      TEXT
      )
    ''');

    // Insert the default settings row so it always exists
    await db.insert('settings', {
      'currency_symbol': 'GH₵',
      'vat_threshold': 750000.0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ══════════════════════════════════════════════════════════
  // BUSINESS PROFILE METHODS
  // ══════════════════════════════════════════════════════════

  // Insert a brand-new business profile (first launch only)
  Future<int> insertProfile(Map<String, dynamic> profile) async {
    final db = await database;
    return await db.insert('business_profile', profile);
  }

  // Get the saved profile — returns null if none exists yet
  Future<Map<String, dynamic>?> getProfile() async {
    final db = await database;
    // query() returns a list; we take the first row if it exists
    final results = await db.query('business_profile', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  // Update the existing profile (called from Settings screen)
  Future<int> updateProfile(Map<String, dynamic> profile) async {
    final db = await database;
    // WHERE id = 1 because there's only ever one profile row
    return await db.update(
      'business_profile',
      profile,
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  // ══════════════════════════════════════════════════════════
  // INCOME METHODS
  // ══════════════════════════════════════════════════════════

  // Insert a new income record; returns the new row's id
  Future<int> insertIncome(Map<String, dynamic> income) async {
    final db = await database;
    return await db.insert('income', income);
  }

  // Get all income records, newest first
  Future<List<Map<String, dynamic>>> getAllIncome() async {
    final db = await database;
    return await db.query('income', orderBy: 'created_at DESC');
  }

  // Get income filtered by a date range (for Reports screen)
  // startDate and endDate are strings like '2026-01-01'
  Future<List<Map<String, dynamic>>> getIncomeByDateRange(
      String startDate, String endDate) async {
    final db = await database;
    return await db.query(
      'income',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC',
    );
  }

  // ── Key VAT query: sum all income for a given year ────────
  // This is called every time new income is recorded.
  // strftime('%Y', date) extracts the 4-digit year from the
  // stored date string (e.g., '2026' from '2026-06-15').
  Future<double> getAnnualTurnover(int year) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM income
      WHERE strftime('%Y', date) = ?
      ''',
      [year.toString()],
    );
    // result is a list of maps; we read the 'total' key
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Monthly income for the current month (Dashboard card)
  Future<double> getMonthlyIncome() async {
    final db = await database;
    // strftime('%Y-%m', 'now') returns e.g. '2026-06'
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM income
      WHERE strftime('%Y-%m', date) = strftime('%Y-%m', 'now')
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Monthly breakdown for bar chart — 6 months of data
  // Returns a list of maps: [{month: '01', total: 1200.0}, ...]
  Future<List<Map<String, dynamic>>> getMonthlyIncomeBreakdown(
      int year) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT strftime('%m', date) AS month,
             COALESCE(SUM(amount), 0) AS total
      FROM income
      WHERE strftime('%Y', date) = ?
      GROUP BY month
      ORDER BY month
    ''', [year.toString()]);
  }

  // Delete a single income record by its id
  Future<int> deleteIncome(int id) async {
    final db = await database;
    return await db.delete('income', where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════
  // EXPENSE METHODS
  // ══════════════════════════════════════════════════════════

  Future<int> insertExpense(Map<String, dynamic> expense) async {
    final db = await database;
    return await db.insert('expenses', expense);
  }

  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    final db = await database;
    return await db.query('expenses', orderBy: 'created_at DESC');
  }

  // Monthly expenses for the current month (Dashboard card)
  Future<double> getMonthlyExpenses() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE strftime('%Y-%m', date) = strftime('%Y-%m', 'now')
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Monthly expense breakdown for bar chart
  Future<List<Map<String, dynamic>>> getMonthlyExpenseBreakdown(
      int year) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT strftime('%m', date) AS month,
             COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE strftime('%Y', date) = ?
      GROUP BY month
      ORDER BY month
    ''', [year.toString()]);
  }

  // Expenses grouped by category — for the pie chart
  Future<List<Map<String, dynamic>>> getExpensesByCategory(int year) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT category, SUM(amount) AS total
      FROM expenses
      WHERE strftime('%Y', date) = ?
      GROUP BY category
      ORDER BY total DESC
    ''', [year.toString()]);
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════
  // SALES METHODS
  // ══════════════════════════════════════════════════════════

  Future<int> insertSale(Map<String, dynamic> sale) async {
    final db = await database;
    return await db.insert('sales', sale);
  }

  Future<List<Map<String, dynamic>>> getAllSales() async {
    final db = await database;
    return await db.query('sales', orderBy: 'created_at DESC');
  }

  Future<int> deleteSale(int id) async {
    final db = await database;
    return await db.delete('sales', where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════
  // RECENT TRANSACTIONS (Dashboard widget)
  // ══════════════════════════════════════════════════════════

  // Returns the last 10 entries from BOTH income and expenses,
  // merged into one list using UNION ALL, newest first.
  Future<List<Map<String, dynamic>>> getRecentTransactions() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT date, description, 'Income' AS type, amount, created_at
      FROM income
      UNION ALL
      SELECT date, description, 'Expense' AS type, amount, created_at
      FROM expenses
      ORDER BY created_at DESC
      LIMIT 10
    ''');
  }

  // ══════════════════════════════════════════════════════════
  // AUDIT REPORT DATA (Year-End PDF)
  // ══════════════════════════════════════════════════════════

  // Get all income for a specific year — used in the audit PDF
  Future<List<Map<String, dynamic>>> getIncomeForYear(int year) async {
    final db = await database;
    return await db.query(
      'income',
      where: "strftime('%Y', date) = ?",
      whereArgs: [year.toString()],
      orderBy: 'date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getExpensesForYear(int year) async {
    final db = await database;
    return await db.query(
      'expenses',
      where: "strftime('%Y', date) = ?",
      whereArgs: [year.toString()],
      orderBy: 'date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getSalesForYear(int year) async {
    final db = await database;
    return await db.query(
      'sales',
      where: "strftime('%Y', date) = ?",
      whereArgs: [year.toString()],
      orderBy: 'date ASC',
    );
  }

  // ══════════════════════════════════════════════════════════
  // BACKUP / RESTORE
  // ══════════════════════════════════════════════════════════

  // Export all data as a Map (later converted to JSON)
  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    // Fetch every row from every table
    final profile  = await db.query('business_profile');
    final income   = await db.query('income');
    final expenses = await db.query('expenses');
    final sales    = await db.query('sales');
    final settings = await db.query('settings');

    // Return as a nested map — easy to convert to JSON
    return {
      'business_profile': profile,
      'income': income,
      'expenses': expenses,
      'sales': sales,
      'settings': settings,
      'exported_at': DateTime.now().toIso8601String(),
      'app_version': '1.0.3',
    };
  }

  // Clear all tables and re-insert data from a backup JSON
  Future<void> restoreFromBackup(Map<String, dynamic> data) async {
    final db = await database;

    // Use a transaction so either ALL data is restored
    // or NONE of it is (prevents partial/corrupt state)
    await db.transaction((txn) async {
      // Wipe all existing data
      await txn.delete('sales');
      await txn.delete('income');
      await txn.delete('expenses');
      await txn.delete('business_profile');
      await txn.delete('settings');

      // Re-insert from backup
      final List profile  = data['business_profile'] ?? [];
      final List income   = data['income'] ?? [];
      final List expenses = data['expenses'] ?? [];
      final List sales    = data['sales'] ?? [];
      final List settings = data['settings'] ?? [];

      for (var row in profile)  await txn.insert('business_profile', Map<String, dynamic>.from(row));
      for (var row in income)   await txn.insert('income',           Map<String, dynamic>.from(row));
      for (var row in expenses) await txn.insert('expenses',         Map<String, dynamic>.from(row));
      for (var row in sales)    await txn.insert('sales',            Map<String, dynamic>.from(row));
      for (var row in settings) await txn.insert('settings',         Map<String, dynamic>.from(row));
    });
  }

  // Delete absolutely everything — used by the "Delete All Data" button
  Future<void> deleteAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sales');
      await txn.delete('income');
      await txn.delete('expenses');
      await txn.delete('business_profile');
      await txn.delete('settings');
    });
  }

  // Count of records in each table — shown on Backup screen
  Future<Map<String, int>> getRecordCounts() async {
    final db = await database;
    Future<int> count(String table) async {
      final r = await db.rawQuery('SELECT COUNT(*) as c FROM $table');
      return (r.first['c'] as int?) ?? 0;
    }
    return {
      'business_profile': await count('business_profile'),
      'income':           await count('income'),
      'expenses':         await count('expenses'),
      'sales':            await count('sales'),
    };
  }
}
