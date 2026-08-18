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
      version: 11,
      onCreate: _createTables,   // Called only when db is brand new
      onUpgrade: _upgradeTables, // Called when an existing db needs new columns/tables
    );
  }

  // ── _upgradeTables: schema migration for existing installs ─
  // version 1 → 2 adds:
  //   • login security columns on `settings` (pin_hash, password_hash, auth_salt)
  //   • `amount_paid` column on `sales` (tracks partial payments)
  //   • the new `sale_payments` table (one row per installment payment)
  // version 2 → 3 adds:
  //   • `profile_image_path` column on `business_profile` (profile picture)
  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE settings ADD COLUMN pin_hash TEXT');
      await db.execute('ALTER TABLE settings ADD COLUMN password_hash TEXT');
      await db.execute('ALTER TABLE settings ADD COLUMN auth_salt TEXT');

      await db.execute('ALTER TABLE sales ADD COLUMN amount_paid REAL NOT NULL DEFAULT 0');

      // Any sale that was already fully 'Paid' before this update
      // is fully paid — backfill amount_paid so balances are correct.
      await db.execute('''
        UPDATE sales SET amount_paid = total_amount WHERE payment_status = 'Paid'
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sale_payments (
          id             INTEGER PRIMARY KEY AUTOINCREMENT,
          sale_id        INTEGER NOT NULL,
          amount         REAL    NOT NULL CHECK(amount > 0),
          payment_method TEXT    NOT NULL,
          date           TEXT    NOT NULL,
          created_at     TEXT    NOT NULL,
          FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('ALTER TABLE business_profile ADD COLUMN profile_image_path TEXT');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS business_documents (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          doc_type     TEXT    NOT NULL,
          file_name    TEXT    NOT NULL,
          file_path    TEXT    NOT NULL,
          uploaded_at  TEXT    NOT NULL
        )
      ''');
    }

    if (oldVersion < 5) {
      // Expenses gain the same Paid / Pending / Partial Payment
      // tracking that Sales already has, plus a companion
      // expense_payments table for the installment history.
      await db.execute("ALTER TABLE expenses ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'Paid'");
      await db.execute('ALTER TABLE expenses ADD COLUMN amount_paid REAL NOT NULL DEFAULT 0');

      // Every pre-existing expense was, by definition, already fully
      // settled — backfill amount_paid so balances come out correct.
      await db.execute('UPDATE expenses SET amount_paid = amount');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS expense_payments (
          id             INTEGER PRIMARY KEY AUTOINCREMENT,
          expense_id     INTEGER NOT NULL,
          amount         REAL    NOT NULL CHECK(amount > 0),
          payment_method TEXT    NOT NULL,
          date           TEXT    NOT NULL,
          created_at     TEXT    NOT NULL,
          FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE CASCADE
        )
      ''');

      // Cheque payment details (optional) for Income, Expenses and
      // Sales — captured only when the payment method is 'Cheque'.
      for (final table in ['income', 'expenses', 'sales']) {
        await db.execute('ALTER TABLE $table ADD COLUMN cheque_account_number TEXT');
        await db.execute('ALTER TABLE $table ADD COLUMN cheque_account_name TEXT');
        await db.execute('ALTER TABLE $table ADD COLUMN cheque_number TEXT');
        await db.execute('ALTER TABLE $table ADD COLUMN cheque_image_path TEXT');
      }
    }

    if (oldVersion < 6) {
      // Unit cost price on each sale — lets us compute Cost of Goods
      // Sold (COGS) and, from there, gross profit / net profit /
      // profit margins. Defaults to 0 (no known cost) so it never
      // breaks existing rows; those sales simply show 100% margin
      // until the owner fills in a cost price going forward.
      await db.execute('ALTER TABLE sales ADD COLUMN cost_price REAL NOT NULL DEFAULT 0');
    }

    if (oldVersion < 7) {
      // Recurring expense templates — rent, salaries, utilities —
      // saved once, logged again with one tap.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recurring_expense_templates (
          id             INTEGER PRIMARY KEY AUTOINCREMENT,
          description    TEXT    NOT NULL,
          category       TEXT    NOT NULL,
          amount         REAL    NOT NULL,
          payment_method TEXT    NOT NULL,
          created_at     TEXT    NOT NULL
        )
      ''');

      // Basic inventory / stock count, tied to Sales
      await db.execute('''
        CREATE TABLE IF NOT EXISTS inventory_items (
          id                  INTEGER PRIMARY KEY AUTOINCREMENT,
          name                TEXT    NOT NULL,
          stock_quantity      INTEGER NOT NULL DEFAULT 0,
          cost_price          REAL    NOT NULL DEFAULT 0,
          selling_price       REAL    NOT NULL DEFAULT 0,
          low_stock_threshold INTEGER NOT NULL DEFAULT 5,
          created_at          TEXT    NOT NULL
        )
      ''');

      // Optional link from a sale back to the inventory item it sold
      // (nullable — sales can still be free-text with no linked item)
      await db.execute('ALTER TABLE sales ADD COLUMN inventory_item_id INTEGER');
    }

    if (oldVersion < 8) {
      // Customers directory — phone/email, kept separate from Sales
      // so contact details survive even if a customer's name is
      // typed slightly differently on a future sale.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          name        TEXT    NOT NULL,
          phone       TEXT,
          email       TEXT,
          created_at  TEXT    NOT NULL
        )
      ''');

      // Advanced inventory details: SKU/code, unit of measure,
      // supplier, and free-form notes.
      await db.execute("ALTER TABLE inventory_items ADD COLUMN sku TEXT");
      await db.execute("ALTER TABLE inventory_items ADD COLUMN supplier TEXT");
      await db.execute("ALTER TABLE inventory_items ADD COLUMN unit TEXT");
      await db.execute("ALTER TABLE inventory_items ADD COLUMN notes TEXT");
    }

    if (oldVersion < 10) {
      // Feature: multi-item sales — several line items recorded
      // together under one customer transaction share this id.
      await db.execute("ALTER TABLE sales ADD COLUMN sale_group_id TEXT");

      // Feature: stock & price audit trail — see
      // _createInventoryChangeLogTable for the full explanation.
      // Created here, BEFORE the oldVersion < 9 block below, so
      // that if a database is jumping from, say, version 7 straight
      // to 10, inventory_change_log already exists by the time
      // _createSyncMetaAndTriggers tries to add triggers to it.
      await _createInventoryChangeLogTable(db);
    }

    if (oldVersion < 9) {
      // Online (Cloud) Sync support — see services/sync_service.dart.
      await _createSyncMetaAndTriggers(db);
    }

    if (oldVersion < 10) {
      // A database already at version 9 (Cloud Sync already set up)
      // upgrading straight to 10 needs ONLY the new trigger added —
      // _createSyncMetaAndTriggers above already ran on a prior
      // upgrade and won't run again, so add it explicitly here too.
      // DROP+CREATE makes this safe to run even if the oldVersion<9
      // branch above already added it moments ago in this same upgrade.
      await db.execute('DROP TRIGGER IF EXISTS trg_sync_inventory_change_log_insert');
      await db.execute('''
        CREATE TRIGGER trg_sync_inventory_change_log_insert
        AFTER INSERT ON inventory_change_log
        BEGIN
          UPDATE sync_meta SET last_modified_at = datetime('now') WHERE id = 1;
        END;
      ''');
    }

    if (oldVersion < 11) {
      // BUGFIX: `settings` (PIN/password hashes, currency symbol,
      // VAT threshold) has always been included in the Cloud Sync
      // payload — see exportAllData()/restoreFromBackup() below —
      // but was missing from `_syncedTables`, so it never got
      // change-tracking triggers. Practical effect: changing your
      // PIN (or the VAT threshold) alone never updated
      // sync_meta.last_modified_at, so the app didn't know that
      // change needed to be pushed — and a later pull could
      // silently overwrite it with the old cloud copy.
      //
      // Re-running _createSyncMetaAndTriggers here is safe even on
      // a database that already has sync set up: every statement
      // inside it is idempotent (CREATE TABLE IF NOT EXISTS,
      // INSERT OR IGNORE, DROP+CREATE TRIGGER). `settings` is now
      // in `_syncedTables`, so this call only ADDS the three
      // triggers that table was missing — it doesn't touch or
      // duplicate anything already set up for the other tables.
      await _createSyncMetaAndTriggers(db);
    }
  }

  // ── inventory_change_log ─────────────────────────────────────
  // One row every time a stock quantity, cost price, or selling
  // price changes on an inventory item — see setInventoryStock,
  // adjustInventoryStock, and updateInventoryPrices below, which
  // are the only three places that ever write to it. Powers the
  // "Change Log" view on the Inventory screen (feature request:
  // an audit trail of stock and price changes with date/time).
  Future<void> _createInventoryChangeLogTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_change_log (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        inventory_item_id  INTEGER NOT NULL,
        item_name          TEXT    NOT NULL,
        field_changed      TEXT    NOT NULL,
        old_value          TEXT    NOT NULL,
        new_value          TEXT    NOT NULL,
        reason             TEXT,
        changed_at         TEXT    NOT NULL
      )
    ''');
  }

  // ── Tables that get change-tracking triggers ────────────────
  // Every table whose data should travel to/from the cloud on a
  // "Sync Now". (Files referenced by *_path columns — profile
  // pictures, cheque photos, business documents — stay local
  // only; only the text/number data syncs.)
  //
  // `settings` is included here (as of schema v11) because it's
  // already part of exportAllData()/restoreFromBackup() below — it
  // holds pin_hash/password_hash/auth_salt, which is what makes
  // "sign in on a new phone restores your old PIN too" work — plus
  // currency_symbol and vat_threshold. Without a trigger here,
  // changes to any of those went untracked by sync_meta even though
  // they were still being pushed/pulled. See the oldVersion < 11
  // migration block above for the upgrade path on existing installs.
  static const List<String> _syncedTables = [
    'business_profile',
    'income',
    'expenses',
    'expense_payments',
    'sales',
    'sale_payments',
    'recurring_expense_templates',
    'inventory_items',
    'customers',
    'inventory_change_log',
    'settings',
  ];

  // ── _createSyncMetaAndTriggers ───────────────────────────────
  // Sets up everything Cloud Sync needs to know "has anything
  // changed on this device since we last talked to the cloud?"
  // WITHOUT having to edit every single insert/update call
  // scattered across the providers and screens.
  //
  // How it works:
  //   1. A tiny single-row `sync_meta` table holds one timestamp:
  //      last_modified_at — "the last time ANY synced table changed
  //      on this device".
  //   2. A SQLite TRIGGER fires automatically after every INSERT,
  //      UPDATE, or DELETE on each synced table and stamps that
  //      timestamp to right now. Triggers live in the database
  //      itself, so they catch changes no matter which Dart method
  //      wrote them.
  //   3. SyncService compares this device's last_modified_at against
  //      last_synced_at (also here) and the cloud's own timestamp to
  //      decide whether to push, pull, or flag a conflict.
  Future<void> _createSyncMetaAndTriggers(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        id                INTEGER PRIMARY KEY CHECK (id = 1),
        last_modified_at  TEXT NOT NULL,
        last_synced_at    TEXT,
        cloud_uid         TEXT
      )
    ''');

    // Only ever one row, id = 1 — INSERT OR IGNORE so re-running
    // this on an already-migrated database is always safe.
    await db.execute('''
      INSERT OR IGNORE INTO sync_meta (id, last_modified_at)
      VALUES (1, '${DateTime.now().toIso8601String()}')
    ''');

    for (final table in _syncedTables) {
      for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
        final triggerName = 'trg_sync_${table}_${event.toLowerCase()}';
        // DROP + CREATE keeps this idempotent across app upgrades
        await db.execute('DROP TRIGGER IF EXISTS $triggerName');
        await db.execute('''
          CREATE TRIGGER $triggerName
          AFTER $event ON $table
          BEGIN
            UPDATE sync_meta
            SET last_modified_at = datetime('now')
            WHERE id = 1;
          END;
        ''');
      }
    }
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
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        business_name       TEXT    NOT NULL,
        owner_name          TEXT    NOT NULL,
        business_type       TEXT    NOT NULL,
        phone               TEXT,
        email               TEXT,
        location            TEXT,
        gra_tin             TEXT,
        vat_number          TEXT,
        profile_image_path  TEXT,
        created_at          TEXT    NOT NULL,
        updated_at          TEXT
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
        cheque_account_number TEXT,
        cheque_account_name   TEXT,
        cheque_number         TEXT,
        cheque_image_path     TEXT,
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
        payment_status TEXT    NOT NULL DEFAULT 'Paid',
        amount_paid    REAL    NOT NULL DEFAULT 0,
        receipt_no     TEXT,
        cheque_account_number TEXT,
        cheque_account_name   TEXT,
        cheque_number         TEXT,
        cheque_image_path     TEXT,
        created_at     TEXT    NOT NULL
      )
    ''');

    // ── Table 3b: expense_payments ─────────────────────────
    // Mirrors sale_payments — one row per installment payment
    // recorded against an expense that's Pending or Partial.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_payments (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_id     INTEGER NOT NULL,
        amount         REAL    NOT NULL CHECK(amount > 0),
        payment_method TEXT    NOT NULL,
        date           TEXT    NOT NULL,
        created_at     TEXT    NOT NULL,
        FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE CASCADE
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
        cost_price       REAL    NOT NULL DEFAULT 0,
        inventory_item_id INTEGER,
        payment_method   TEXT    NOT NULL,
        payment_status   TEXT    NOT NULL DEFAULT 'Paid',
        amount_paid      REAL    NOT NULL DEFAULT 0,
        notes            TEXT,
        income_id        INTEGER,
        cheque_account_number TEXT,
        cheque_account_name   TEXT,
        cheque_number         TEXT,
        cheque_image_path     TEXT,
        sale_group_id    TEXT,
        created_at       TEXT    NOT NULL,
        FOREIGN KEY (income_id) REFERENCES income(id)
      )
    ''');

    // ── Table 4b: sale_payments ────────────────────────────
    // One row per installment payment recorded against a sale.
    // Lets us show a full payment history for Pending/Partial sales.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_payments (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id        INTEGER NOT NULL,
        amount         REAL    NOT NULL CHECK(amount > 0),
        payment_method TEXT    NOT NULL,
        date           TEXT    NOT NULL,
        created_at     TEXT    NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE
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
        pin_hash        TEXT,
        password_hash   TEXT,
        auth_salt       TEXT,
        updated_at      TEXT
      )
    ''');

    // Insert the default settings row so it always exists
    await db.insert('settings', {
      'currency_symbol': 'GH₵',
      'vat_threshold': 750000.0,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // ── Table 6: business_documents ────────────────────────
    // Advanced Settings feature: lets a business owner attach
    // PDF copies of certificates/licenses (e.g. Certificate of
    // Incorporation, SSNIT Clearance) that are commonly needed
    // when applying for tenders/bids, so they're all in one place.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS business_documents (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        doc_type     TEXT    NOT NULL,
        file_name    TEXT    NOT NULL,
        file_path    TEXT    NOT NULL,
        uploaded_at  TEXT    NOT NULL
      )
    ''');

    // ── Table 7: recurring_expense_templates ────────────────
    // Rent, salaries, utilities — saved once, logged again in
    // one tap from the Expenses screen.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_expense_templates (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        description    TEXT    NOT NULL,
        category       TEXT    NOT NULL,
        amount         REAL    NOT NULL,
        payment_method TEXT    NOT NULL,
        created_at     TEXT    NOT NULL
      )
    ''');

    // ── Table 8: inventory_items ─────────────────────────────
    // Basic stock count per item, tied to Sales via
    // sales.inventory_item_id.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_items (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        name                TEXT    NOT NULL,
        stock_quantity      INTEGER NOT NULL DEFAULT 0,
        cost_price          REAL    NOT NULL DEFAULT 0,
        selling_price       REAL    NOT NULL DEFAULT 0,
        low_stock_threshold INTEGER NOT NULL DEFAULT 5,
        sku                 TEXT,
        supplier            TEXT,
        unit                TEXT,
        notes               TEXT,
        created_at          TEXT    NOT NULL
      )
    ''');

    // ── Table 9: customers ───────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        phone       TEXT,
        email       TEXT,
        created_at  TEXT    NOT NULL
      )
    ''');

    // ── Table 10: sync_meta + change-tracking triggers ────────
    // See _createSyncMetaAndTriggers for the full explanation.
    // inventory_change_log is created FIRST so the trigger-creation
    // loop inside _createSyncMetaAndTriggers finds it already there.
    await _createInventoryChangeLogTable(db);
    await _createSyncMetaAndTriggers(db);
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

  // ── recordExpensePayment: the "finish paying" operation ─────
  // Mirrors recordSalePayment — writes the installment history
  // row and the expense's updated running total in one transaction.
  Future<void> recordExpensePayment({
    required int expenseId,
    required Map<String, dynamic> updatedExpense,
    required Map<String, dynamic> payment,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('expense_payments', payment);
      await txn.update('expenses', updatedExpense, where: 'id = ?', whereArgs: [expenseId]);
    });
  }

  // All installment payments recorded against one expense, oldest first
  Future<List<Map<String, dynamic>>> getPaymentsForExpense(int expenseId) async {
    final db = await database;
    return await db.query(
      'expense_payments',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
      orderBy: 'created_at ASC',
    );
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

  // Update an existing sale row (used when a payment changes its
  // amount_paid / payment_status / income_id)
  Future<int> updateSale(int id, Map<String, dynamic> sale) async {
    final db = await database;
    return await db.update('sales', sale, where: 'id = ?', whereArgs: [id]);
  }

  // ── getSalesSummaryForRange: powers the Sales Performance report ─
  // Returns total units sold, total revenue, and a per-item
  // breakdown (both sorted by units sold, most first) for any
  // date range — the caller works out what "Day/Week/Month/Year"
  // actually means in calendar terms and just passes the two
  // resulting 'YYYY-MM-DD' bounds in here.
  Future<Map<String, dynamic>> getSalesSummaryForRange(String startDate, String endDate) async {
    final db = await database;

    final totals = await db.rawQuery('''
      SELECT COALESCE(SUM(quantity), 0)     AS qty,
             COALESCE(SUM(total_amount), 0) AS revenue,
             COUNT(*)                       AS transaction_count
      FROM sales
      WHERE date BETWEEN ? AND ?
    ''', [startDate, endDate]);

    final byItem = await db.rawQuery('''
      SELECT item_description                AS name,
             SUM(quantity)                   AS qty,
             SUM(total_amount)                AS revenue
      FROM sales
      WHERE date BETWEEN ? AND ?
      GROUP BY item_description
      ORDER BY qty DESC
    ''', [startDate, endDate]);

    return {
      'totalQuantity':     (totals.first['qty'] as num).toInt(),
      'totalRevenue':      (totals.first['revenue'] as num).toDouble(),
      'transactionCount':  (totals.first['transaction_count'] as num).toInt(),
      'items': byItem.map((r) => {
            'name':    r['name'] as String,
            'qty':     (r['qty'] as num).toInt(),
            'revenue': (r['revenue'] as num).toDouble(),
          }).toList(),
    };
  }


  // Runs as a single transaction so the payment history row and
  // the sale's updated totals are always written together —
  // never one without the other.
  //   updatedSale: the full new sales row (amount_paid, payment_status,
  //                income_id already recalculated by SalesProvider)
  //   payment:     the new sale_payments row to insert
  Future<void> recordSalePayment({
    required int saleId,
    required Map<String, dynamic> updatedSale,
    required Map<String, dynamic> payment,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('sale_payments', payment);
      await txn.update('sales', updatedSale, where: 'id = ?', whereArgs: [saleId]);
    });
  }

  // All installment payments recorded against one sale, oldest first
  // (so the payment history reads top-to-bottom like a statement)
  Future<List<Map<String, dynamic>>> getPaymentsForSale(int saleId) async {
    final db = await database;
    return await db.query(
      'sale_payments',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'created_at ASC',
    );
  }

  // ══════════════════════════════════════════════════════════
  // CUSTOMER LEDGER (aggregate balance owed, per customer)
  // ══════════════════════════════════════════════════════════

  // One row per distinct customer name that appears on at least one
  // sale, with their totals rolled up across every sale they've
  // ever been on — this is what "who owes me money" looks like.
  Future<List<Map<String, dynamic>>> getCustomerLedger() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT customer_name,
             COUNT(*)                              AS transaction_count,
             COALESCE(SUM(total_amount), 0)         AS total_sales,
             COALESCE(SUM(amount_paid), 0)          AS total_paid,
             COALESCE(SUM(total_amount - amount_paid), 0) AS balance_owed,
             MAX(date)                              AS last_sale_date
      FROM sales
      WHERE customer_name IS NOT NULL AND TRIM(customer_name) != ''
      GROUP BY customer_name
      ORDER BY balance_owed DESC, total_sales DESC
    ''');
  }

  // Every sale for one customer, newest first — opened when the
  // owner taps into a customer's row on the ledger.
  Future<List<Map<String, dynamic>>> getSalesForCustomer(String customerName) async {
    final db = await database;
    return await db.query(
      'sales',
      where: 'customer_name = ?',
      whereArgs: [customerName],
      orderBy: 'date DESC',
    );
  }

  // ══════════════════════════════════════════════════════════
  // RECURRING EXPENSE TEMPLATES (rent, salaries, utilities…)
  // ══════════════════════════════════════════════════════════

  Future<int> insertRecurringExpenseTemplate(Map<String, dynamic> template) async {
    final db = await database;
    return await db.insert('recurring_expense_templates', template);
  }

  Future<List<Map<String, dynamic>>> getRecurringExpenseTemplates() async {
    final db = await database;
    return await db.query('recurring_expense_templates', orderBy: 'description ASC');
  }

  Future<int> deleteRecurringExpenseTemplate(int id) async {
    final db = await database;
    return await db.delete('recurring_expense_templates', where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════
  // INVENTORY / STOCK
  // ══════════════════════════════════════════════════════════

  Future<int> insertInventoryItem(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert('inventory_items', item);
  }

  Future<List<Map<String, dynamic>>> getInventoryItems() async {
    final db = await database;
    return await db.query('inventory_items', orderBy: 'name ASC');
  }

  Future<int> updateInventoryItem(int id, Map<String, dynamic> item) async {
    final db = await database;
    return await db.update('inventory_items', item, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteInventoryItem(int id) async {
    final db = await database;
    return await db.delete('inventory_items', where: 'id = ?', whereArgs: [id]);
  }

  // Writes one row to inventory_change_log. Private — every stock
  // or price change in this file goes through here so the audit
  // trail can never silently miss an entry.
  Future<void> _logInventoryChange(
    Database db, {
    required int itemId,
    required String itemName,
    required String field,
    required String oldValue,
    required String newValue,
    String? reason,
  }) async {
    if (oldValue == newValue) return; // Nothing actually changed — don't log a no-op
    await db.insert('inventory_change_log', {
      'inventory_item_id': itemId,
      'item_name':         itemName,
      'field_changed':     field,
      'old_value':         oldValue,
      'new_value':         newValue,
      'reason':            reason,
      'changed_at':        DateTime.now().toIso8601String(),
    });
  }

  // Adjusts stock_quantity by +/- delta (delta is negative for a
  // sale, positive for a restock). Clamped at 0 so stock never goes
  // negative in the display, even if oversold. Every call is logged
  // to inventory_change_log — this is the ONE place both the quick
  // +/- buttons on the Inventory screen AND an automatic sale-time
  // decrement pass through, so nothing that touches stock ever goes
  // unlogged.
  Future<void> adjustInventoryStock(int itemId, int delta, {String reason = 'Manual Adjustment'}) async {
    final db = await database;
    final rows = await db.query('inventory_items', where: 'id = ?', whereArgs: [itemId], limit: 1);
    if (rows.isEmpty) return;
    final current = rows.first['stock_quantity'] as int;
    final name = rows.first['name'] as String;
    final updated = (current + delta) < 0 ? 0 : current + delta;
    await db.update('inventory_items', {'stock_quantity': updated}, where: 'id = ?', whereArgs: [itemId]);
    await _logInventoryChange(
      db,
      itemId: itemId,
      itemName: name,
      field: 'stock_quantity',
      oldValue: '$current',
      newValue: '$updated',
      reason: reason,
    );
  }

  // Sets stock to an EXACT new number (e.g. after a physical stock
  // count) rather than nudging it by a delta. This is the "accept a
  // new number in stock" action the Inventory screen requires PIN
  // re-authentication for before calling this.
  Future<void> setInventoryStock(int itemId, int newQuantity, {String reason = 'Stock Count Correction'}) async {
    final db = await database;
    final rows = await db.query('inventory_items', where: 'id = ?', whereArgs: [itemId], limit: 1);
    if (rows.isEmpty) return;
    final current = rows.first['stock_quantity'] as int;
    final name = rows.first['name'] as String;
    final clamped = newQuantity < 0 ? 0 : newQuantity;
    await db.update('inventory_items', {'stock_quantity': clamped}, where: 'id = ?', whereArgs: [itemId]);
    await _logInventoryChange(
      db,
      itemId: itemId,
      itemName: name,
      field: 'stock_quantity',
      oldValue: '$current',
      newValue: '$clamped',
      reason: reason,
    );
  }

  // Edits cost price and/or selling price — e.g. when market prices
  // change. Sale unit cost price is deliberately NOT editable from
  // the Sales screen; this is the only path to change it, and every
  // change lands in inventory_change_log with old/new values.
  Future<void> updateInventoryPrices(
    int itemId, {
    double? costPrice,
    double? sellingPrice,
    String reason = 'Price Update',
  }) async {
    final db = await database;
    final rows = await db.query('inventory_items', where: 'id = ?', whereArgs: [itemId], limit: 1);
    if (rows.isEmpty) return;
    final row = rows.first;
    final name = row['name'] as String;
    final currentCost = (row['cost_price'] as num).toDouble();
    final currentSelling = (row['selling_price'] as num).toDouble();

    final updates = <String, dynamic>{};
    if (costPrice != null && costPrice != currentCost) updates['cost_price'] = costPrice;
    if (sellingPrice != null && sellingPrice != currentSelling) updates['selling_price'] = sellingPrice;
    if (updates.isEmpty) return;

    await db.update('inventory_items', updates, where: 'id = ?', whereArgs: [itemId]);

    if (updates.containsKey('cost_price')) {
      await _logInventoryChange(
        db,
        itemId: itemId,
        itemName: name,
        field: 'cost_price',
        oldValue: currentCost.toStringAsFixed(2),
        newValue: costPrice!.toStringAsFixed(2),
        reason: reason,
      );
    }
    if (updates.containsKey('selling_price')) {
      await _logInventoryChange(
        db,
        itemId: itemId,
        itemName: name,
        field: 'selling_price',
        oldValue: currentSelling.toStringAsFixed(2),
        newValue: sellingPrice!.toStringAsFixed(2),
        reason: reason,
      );
    }
  }

  // Full change history, most recent first — optionally scoped to
  // one item (pass itemId), or across every item (pass null) for
  // the "All Items" view on the Change Log screen.
  Future<List<Map<String, dynamic>>> getInventoryChangeLogs({int? itemId}) async {
    final db = await database;
    if (itemId != null) {
      return await db.query(
        'inventory_change_log',
        where: 'inventory_item_id = ?',
        whereArgs: [itemId],
        orderBy: 'changed_at DESC',
      );
    }
    return await db.query('inventory_change_log', orderBy: 'changed_at DESC');
  }

  // Which inventory items have sold the most (by quantity), so the
  // owner knows what to restock first to keep cash moving. Only
  // counts sales that were actually linked to an inventory item.
  Future<List<Map<String, dynamic>>> getBestSellingItems({int limit = 10}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT i.id, i.name, i.stock_quantity,
             COALESCE(SUM(s.quantity), 0)            AS units_sold,
             COALESCE(SUM(s.total_amount), 0)         AS revenue
      FROM inventory_items i
      LEFT JOIN sales s ON s.inventory_item_id = i.id
      GROUP BY i.id
      ORDER BY units_sold DESC
      LIMIT ?
    ''', [limit]);
  }

  // ══════════════════════════════════════════════════════════
  // CUSTOMERS (contact directory, separate from Sales)
  // ══════════════════════════════════════════════════════════

  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final db = await database;
    return await db.insert('customers', customer);
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await database;
    return await db.query('customers', orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getCustomerByName(String name) async {
    final db = await database;
    final rows = await db.query('customers', where: 'name = ?', whereArgs: [name], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> updateCustomer(int id, Map<String, dynamic> customer) async {
    final db = await database;
    return await db.update('customers', customer, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════
  // GLOBAL SEARCH (Income + Expenses + Sales)
  // ══════════════════════════════════════════════════════════

  // One combined, newest-first result set across all three record
  // types, matched against description/category/customer name.
  Future<List<Map<String, dynamic>>> globalSearch(String query) async {
    final db = await database;
    final like = '%$query%';
    return await db.rawQuery('''
      SELECT id, date, description, category, amount, 'Income' AS record_type, NULL AS extra
      FROM income
      WHERE description LIKE ? OR category LIKE ?
      UNION ALL
      SELECT id, date, description, category, amount, 'Expense' AS record_type, payment_status AS extra
      FROM expenses
      WHERE description LIKE ? OR category LIKE ?
      UNION ALL
      SELECT id, date, item_description AS description, customer_name AS category, total_amount AS amount,
             'Sale' AS record_type, payment_status AS extra
      FROM sales
      WHERE item_description LIKE ? OR customer_name LIKE ?
      ORDER BY date DESC
      LIMIT 100
    ''', [like, like, like, like, like, like]);
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
  // PROFIT / ANALYTICS METHODS
  // ══════════════════════════════════════════════════════════
  // Cost of Goods Sold (COGS) = Σ(quantity × cost_price) across
  // sales. Combined with Income and Expenses elsewhere, this is
  // what powers Gross Profit / Net Profit / margins.

  Future<double> getAnnualCogs(int year) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(quantity * cost_price), 0) AS total
      FROM sales
      WHERE strftime('%Y', date) = ?
    ''', [year.toString()]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Monthly COGS for the current month (Dashboard profit cards)
  Future<double> getMonthlyCogs() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(quantity * cost_price), 0) AS total
      FROM sales
      WHERE strftime('%Y-%m', date) = strftime('%Y-%m', 'now')
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // COGS broken down by month, for the Gross Profit trend chart
  Future<List<Map<String, dynamic>>> getMonthlyCogsBreakdown(int year) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT strftime('%m', date) AS month,
             COALESCE(SUM(quantity * cost_price), 0) AS total
      FROM sales
      WHERE strftime('%Y', date) = ?
      GROUP BY month
      ORDER BY month
    ''', [year.toString()]);
  }

  // Total sales value by month (distinct from Income, which only
  // counts sales once they're fully Paid) — used on the Analytics
  // screen to compare sales volume period over period.
  Future<List<Map<String, dynamic>>> getMonthlySalesBreakdown(int year) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT strftime('%m', date) AS month,
             COALESCE(SUM(total_amount), 0) AS total
      FROM sales
      WHERE strftime('%Y', date) = ?
      GROUP BY month
      ORDER BY month
    ''', [year.toString()]);
  }

  // Every distinct year that has at least one income, expense, or
  // sales record — powers the year picker on the Analytics screen.
  Future<List<int>> getYearsWithData() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT strftime('%Y', date) AS y FROM income
      UNION SELECT DISTINCT strftime('%Y', date) AS y FROM expenses
      UNION SELECT DISTINCT strftime('%Y', date) AS y FROM sales
      ORDER BY y DESC
    ''');
    return result
        .map((row) => int.tryParse(row['y'] as String? ?? ''))
        .whereType<int>()
        .toList();
  }

  // ══════════════════════════════════════════════════════════
  // ONLINE / CLOUD SYNC
  // ══════════════════════════════════════════════════════════
  // These four methods are the ONLY thing SyncService touches
  // directly on the database — everything else it needs
  // (exportAllData / restoreFromBackup) already existed for the
  // local JSON backup feature and is reused as-is.

  // Reads the single sync_meta row. Returns null only if the
  // database somehow predates version 9 and hasn't upgraded yet.
  Future<Map<String, dynamic>?> getSyncMeta() async {
    final db = await database;
    final rows = await db.query('sync_meta', where: 'id = 1', limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  // Called right after a successful push OR pull so this device
  // knows it's caught up as of `syncedAt` (which SyncService sets
  // to the value BOTH sides agreed on, not just `DateTime.now()`,
  // so clock drift between two devices can't cause false conflicts).
  Future<void> markSynced({required DateTime syncedAt, required String cloudUid}) async {
    final db = await database;
    await db.update(
      'sync_meta',
      {
        'last_synced_at': syncedAt.toIso8601String(),
        'cloud_uid': cloudUid,
      },
      where: 'id = 1',
    );
  }

  // Used only when restoring a cloud snapshot onto this device —
  // stamps last_modified_at forward too, so we don't immediately
  // think we have "new" local changes to push right back up.
  Future<void> setSyncTimestamps({required DateTime modifiedAt, required DateTime syncedAt}) async {
    final db = await database;
    await db.update(
      'sync_meta',
      {
        'last_modified_at': modifiedAt.toIso8601String(),
        'last_synced_at': syncedAt.toIso8601String(),
      },
      where: 'id = 1',
    );
  }

  // ══════════════════════════════════════════════════════════
  // BACKUP / RESTORE
  // ══════════════════════════════════════════════════════════

  // Export all data as a Map (later converted to JSON).
  // Used by BOTH the local "Export Backup" file feature and
  // SyncService when pushing a snapshot to the cloud.
  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    // Fetch every row from every table
    final profile            = await db.query('business_profile');
    final income             = await db.query('income');
    final expenses           = await db.query('expenses');
    final expensePayments    = await db.query('expense_payments');
    final sales              = await db.query('sales');
    final salePayments       = await db.query('sale_payments');
    final recurringTemplates = await db.query('recurring_expense_templates');
    final inventoryItems     = await db.query('inventory_items');
    final customers          = await db.query('customers');
    final inventoryChangeLog = await db.query('inventory_change_log');
    final settings           = await db.query('settings');

    // Return as a nested map — easy to convert to JSON
    return {
      'business_profile': profile,
      'income': income,
      'expenses': expenses,
      'expense_payments': expensePayments,
      'sales': sales,
      'sale_payments': salePayments,
      'recurring_expense_templates': recurringTemplates,
      'inventory_items': inventoryItems,
      'customers': customers,
      'inventory_change_log': inventoryChangeLog,
      'settings': settings,
      'exported_at': DateTime.now().toIso8601String(),
      'app_version': '1.1.0',
    };
  }

  // Clear all tables and re-insert data from a backup JSON
  Future<void> restoreFromBackup(Map<String, dynamic> data) async {
    final db = await database;

    // Use a transaction so either ALL data is restored
    // or NONE of it is (prevents partial/corrupt state)
    await db.transaction((txn) async {
      // Wipe all existing data — children before parents, so
      // foreign key references never dangle mid-transaction
      await txn.delete('expense_payments');
      await txn.delete('sale_payments');
      await txn.delete('sales');
      await txn.delete('income');
      await txn.delete('expenses');
      await txn.delete('recurring_expense_templates');
      await txn.delete('inventory_items');
      await txn.delete('customers');
      await txn.delete('inventory_change_log');
      await txn.delete('business_profile');
      await txn.delete('settings');

      // Re-insert from backup. `?? []` means older backup files
      // (or cloud snapshots from before a table existed) restore
      // fine — the newer table just comes back empty.
      final List profile            = data['business_profile'] ?? [];
      final List income              = data['income'] ?? [];
      final List expenses            = data['expenses'] ?? [];
      final List expensePayments      = data['expense_payments'] ?? [];
      final List sales                = data['sales'] ?? [];
      final List salePayments         = data['sale_payments'] ?? [];
      final List recurringTemplates   = data['recurring_expense_templates'] ?? [];
      final List inventoryItems       = data['inventory_items'] ?? [];
      final List customers            = data['customers'] ?? [];
      final List inventoryChangeLog   = data['inventory_change_log'] ?? [];
      final List settings             = data['settings'] ?? [];

      // Parents first, then anything that can reference them, so
      // this stays safe even if FK enforcement is ever turned on.
      for (var row in profile)            await txn.insert('business_profile', Map<String, dynamic>.from(row));
      for (var row in settings)           await txn.insert('settings', Map<String, dynamic>.from(row));
      for (var row in customers)          await txn.insert('customers', Map<String, dynamic>.from(row));
      for (var row in inventoryItems)     await txn.insert('inventory_items', Map<String, dynamic>.from(row));
      for (var row in recurringTemplates) await txn.insert('recurring_expense_templates', Map<String, dynamic>.from(row));
      for (var row in income)             await txn.insert('income', Map<String, dynamic>.from(row));
      for (var row in expenses)           await txn.insert('expenses', Map<String, dynamic>.from(row));
      for (var row in sales)              await txn.insert('sales', Map<String, dynamic>.from(row));
      for (var row in expensePayments)    await txn.insert('expense_payments', Map<String, dynamic>.from(row));
      for (var row in salePayments)       await txn.insert('sale_payments', Map<String, dynamic>.from(row));
      for (var row in inventoryChangeLog) await txn.insert('inventory_change_log', Map<String, dynamic>.from(row));
    });
  }

  // Delete absolutely everything — used by the "Delete All Data" button.
  // NOTE: this also clears the login PIN/password, since there's no
  // longer any data left to protect — the app will ask the user to
  // set up a new PIN the next time they complete onboarding.
  Future<void> deleteAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sale_payments');
      await txn.delete('sales');
      await txn.delete('expense_payments');
      await txn.delete('income');
      await txn.delete('expenses');
      await txn.delete('business_profile');
      await txn.delete('business_documents');
      await txn.delete('recurring_expense_templates');
      await txn.delete('inventory_items');
      await txn.delete('customers');
      await txn.delete('inventory_change_log');
      await txn.delete('settings');
    });
  }

  // ══════════════════════════════════════════════════════════
  // BUSINESS DOCUMENTS METHODS
  // ══════════════════════════════════════════════════════════
  // Advanced Settings feature — lets a business owner attach PDF
  // copies of certificates/licenses commonly needed for tender or
  // bid applications (e.g. Certificate of Incorporation, SSNIT
  // Clearance), all kept alongside the rest of the business profile.

  // Insert (or, if this doc_type is being replaced, overwrite) a
  // saved document record. Each doc_type only ever has one active row.
  Future<int> upsertBusinessDocument(Map<String, dynamic> doc) async {
    final db = await database;
    final existing = await db.query(
      'business_documents',
      where: 'doc_type = ?',
      whereArgs: [doc['doc_type']],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return await db.update(
        'business_documents',
        doc,
        where: 'doc_type = ?',
        whereArgs: [doc['doc_type']],
      );
    }
    return await db.insert('business_documents', doc);
  }

  // Get every attached document, keyed by doc_type for easy lookup
  Future<List<Map<String, dynamic>>> getBusinessDocuments() async {
    final db = await database;
    return await db.query('business_documents', orderBy: 'doc_type ASC');
  }

  // Remove an attached document record (the underlying PDF file is
  // removed separately by the caller, which knows its file path)
  Future<int> deleteBusinessDocument(String docType) async {
    final db = await database;
    return await db.delete(
      'business_documents',
      where: 'doc_type = ?',
      whereArgs: [docType],
    );
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

  // ══════════════════════════════════════════════════════════
  // LOGIN SECURITY (PIN + backup password)
  // ══════════════════════════════════════════════════════════
  // We never store the actual PIN or password — only a salted
  // SHA-256 hash of each (see utils/auth_helper.dart). These live
  // on the single settings row (id = 1) alongside currency/VAT
  // settings, so no extra table is needed.

  // Returns the settings row containing pin_hash/password_hash/auth_salt,
  // or null if no settings row exists yet (e.g. right after Delete All Data)
  Future<Map<String, dynamic>?> getAuthCredentials() async {
    final db = await database;
    final rows = await db.query('settings', limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  // Save (or overwrite) the PIN/password hashes. Handles both cases:
  //   • a settings row already exists → UPDATE it
  //   • no settings row exists (e.g. after Delete All Data) → INSERT a fresh one
  Future<void> saveAuthCredentials({
    required String pinHash,
    required String passwordHash,
    required String salt,
  }) async {
    final db = await database;
    final existing = await db.query('settings', limit: 1);

    final values = {
      'pin_hash': pinHash,
      'password_hash': passwordHash,
      'auth_salt': salt,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (existing.isNotEmpty) {
      await db.update('settings', values, where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      await db.insert('settings', {
        'currency_symbol': 'GH₵',
        'vat_threshold': 750000.0,
        ...values,
      });
    }
  }

  // ── Opportunistic hash-format upgrade ────────────────────────
  // Called by AuthProvider right after a PIN/password typed on the
  // Lock Screen is confirmed correct AND its stored hash turns out
  // to still be in the old, pre-PBKDF2 format (see AuthHelper).
  // Re-saves just that one column with the new iterated hash so the
  // upgrade happens silently over time, one successful login at a
  // time, with no forced "reset your PIN" step for the business
  // owner. Each of these is its own tiny UPDATE (rather than going
  // through saveAuthCredentials) so upgrading the PIN hash never
  // touches — or accidentally clobbers — the password hash, or vice
  // versa, if only one of the two has been typed recently.
  // NOTE: unlike sync_meta (CHECK (id = 1)), `settings`'s id is a
  // plain AUTOINCREMENT — after a "Delete All Data" + fresh
  // saveAuthCredentials insert, its single row is NOT guaranteed to
  // still have id 1. So, same as saveAuthCredentials above, we look
  // up the current row's real id rather than assuming it.
  Future<void> updatePinHash(String newHash) async {
    final db = await database;
    final existing = await db.query('settings', limit: 1);
    if (existing.isEmpty) return; // nothing to upgrade — shouldn't happen mid-verify
    await db.update(
      'settings',
      {'pin_hash': newHash, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [existing.first['id']],
    );
  }

  Future<void> updatePasswordHash(String newHash) async {
    final db = await database;
    final existing = await db.query('settings', limit: 1);
    if (existing.isEmpty) return;
    await db.update(
      'settings',
      {'password_hash': newHash, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [existing.first['id']],
    );
  }
}
