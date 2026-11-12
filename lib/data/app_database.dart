import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Opens the on-device database and runs migrations.
///
/// Conventions for every table:
/// - money columns are INTEGER centavos
/// - ids are UUID text, and every table has `updated_at` (for later sync)
/// - timestamps are ISO 8601 UTC text, `business_date` is `YYYY-MM-DD`
/// - rows are voided or archived with a flag, never deleted
class AppDatabase {
  static const String fileName = 'shop.db';
  static const int schemaVersion = 2;

  /// Where the real database file lives on the phone.
  static Future<String> defaultPath() async =>
      p.join(await databaseFactory.getDatabasesPath(), fileName);

  /// [singleInstance] false gives a separate connection, used for the
  /// tutorial's in-memory demo database.
  ///
  /// With [keepCopyBeforeUpgrade], a database file made by an older version
  /// of the app is copied aside before it is upgraded.
  static Future<Database> open({
    DatabaseFactory? factory,
    String? path,
    bool singleInstance = true,
    bool keepCopyBeforeUpgrade = false,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), fileName);
    if (keepCopyBeforeUpgrade) await _copyBeforeUpgrade(dbFactory, dbPath);
    return dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        singleInstance: singleInstance,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
  }

  /// The copy kept beside [dbPath] before an upgrade to this version.
  static String copyBeforeUpgradePath(String dbPath) =>
      p.join(p.dirname(dbPath), 'shop_before_v$schemaVersion.db');

  /// A safety net: the app never reads this copy. Failing to make it must
  /// not stop the app from opening.
  static Future<void> _copyBeforeUpgrade(
    DatabaseFactory factory,
    String dbPath,
  ) async {
    try {
      final file = File(dbPath);
      if (!await file.exists()) return;
      final db = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      final version = await db.getVersion();
      await db.close();
      if (version < 1 || version >= schemaVersion) return;
      await file.copy(copyBeforeUpgradePath(dbPath));
    } catch (_) {}
  }

  /// Add a new entry here and raise [schemaVersion] to change the schema.
  /// A migration may only add tables and columns. Phones and backup files
  /// hold real records made by every earlier version.
  static final Map<int, Future<void> Function(Database)> _migrations = {
    1: _v1,
    2: _v2,
  };

  static Future<void> _migrate(Database db, int from, int to) async {
    for (var version = from + 1; version <= to; version++) {
      await _migrations[version]!(db);
    }
  }

  static Future<void> _v1(Database db) async {
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        shop_name TEXT NOT NULL,
        staff_label TEXT NOT NULL,
        default_staff_percent INTEGER NOT NULL
          CHECK (default_staff_percent BETWEEN 0 AND 100),
        appearance TEXT NOT NULL CHECK (appearance IN ('system', 'light', 'dark')),
        language TEXT NOT NULL,
        pin_hash TEXT,
        last_backup_at TEXT,
        tutorial_seen INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE staff (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('regular', 'reliever')),
        percent_override INTEGER
          CHECK (percent_override IS NULL OR percent_override BETWEEN 0 AND 100),
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE services (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price INTEGER NOT NULL CHECK (price >= 0),
        active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE expense_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    // service_name, price and staff_percent are copied at the time of sale so
    // later price or split changes never alter past sales.
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        business_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        staff_id TEXT NOT NULL REFERENCES staff (id),
        service_id TEXT REFERENCES services (id),
        service_name TEXT NOT NULL,
        price INTEGER NOT NULL CHECK (price >= 0),
        staff_percent INTEGER NOT NULL CHECK (staff_percent BETWEEN 0 AND 100),
        staff_share INTEGER NOT NULL,
        shop_share INTEGER NOT NULL,
        tip INTEGER NOT NULL DEFAULT 0 CHECK (tip >= 0),
        tip_held INTEGER NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'gcash')),
        note TEXT,
        voided INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE staff_payments (
        id TEXT PRIMARY KEY,
        business_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        staff_id TEXT NOT NULL REFERENCES staff (id),
        type TEXT NOT NULL CHECK (type IN ('payout', 'advance', 'adjustment')),
        amount INTEGER NOT NULL,
        payment_method TEXT CHECK (payment_method IN ('cash', 'gcash')),
        note TEXT,
        voided INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        business_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        category TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK (amount >= 0),
        payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'gcash')),
        note TEXT,
        voided INTEGER NOT NULL DEFAULT 0
      )
    ''');
    // A row here means the day is locked.
    await db.execute('''
      CREATE TABLE day_closures (
        business_date TEXT PRIMARY KEY,
        closed_at TEXT NOT NULL,
        cash_counted INTEGER,
        note TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_sales_date ON sales (business_date)');
    await db.execute('CREATE INDEX idx_sales_staff ON sales (staff_id)');
    await db.execute(
      'CREATE INDEX idx_staff_payments_date ON staff_payments (business_date)',
    );
    await db.execute(
      'CREATE INDEX idx_staff_payments_staff ON staff_payments (staff_id)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_date ON expenses (business_date)',
    );

    final now = nowIso();
    await db.insert('settings', {
      'id': 1,
      'shop_name': 'Barbershop',
      'staff_label': 'Barber',
      'default_staff_percent': 60,
      'appearance': 'light',
      'language': 'en',
      'tutorial_seen': 0,
      'updated_at': now,
    });
    const categories = ['Rent', 'Electricity', 'Water', 'Supplies', 'Other'];
    for (var i = 0; i < categories.length; i++) {
      await db.insert('expense_categories', {
        'id': newId(),
        'name': categories[i],
        'active': 1,
        'sort_order': i,
        'updated_at': now,
      });
    }
  }

  /// Version 2: tally batches, the log of reopened days, and a switch for
  /// asking the PIN when the app opens.
  static Future<void> _v2(Database db) async {
    // Sales saved together from the past-day tally share one batch id.
    await db.execute('ALTER TABLE sales ADD COLUMN batch_id TEXT');
    await db.execute(
      'CREATE INDEX idx_sales_batch ON sales (batch_id) '
      'WHERE batch_id IS NOT NULL',
    );
    // One row each time a closed day is reopened. A log only: rows are
    // added, never changed. `reason` is plain text so new reasons need no
    // migration.
    await db.execute('''
      CREATE TABLE day_reopens (
        id TEXT PRIMARY KEY,
        business_date TEXT NOT NULL,
        reopened_at TEXT NOT NULL,
        reason TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_day_reopens_date ON day_reopens (business_date)',
    );
    // 1 keeps the behavior of version 1: a PIN also locks the app.
    await db.execute(
      'ALTER TABLE settings ADD COLUMN lock_on_open INTEGER NOT NULL DEFAULT 1',
    );
  }
}

const Uuid _uuid = Uuid();

String newId() => _uuid.v4();

String nowIso() => DateTime.now().toUtc().toIso8601String();
