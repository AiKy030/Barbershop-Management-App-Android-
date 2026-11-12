import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';
import 'app_database.dart';

/// All database access for the Settings data goes through these classes.

class SettingsRepository {
  SettingsRepository(this._db);
  final Database _db;

  Future<ShopSettings> load() async {
    final row = (await _db.query('settings', where: 'id = 1')).single;
    final lastBackup = row['last_backup_at'] as String?;
    return ShopSettings(
      shopName: row['shop_name'] as String,
      staffLabel: row['staff_label'] as String,
      defaultStaffPercent: row['default_staff_percent'] as int,
      appearance: AppearanceMode.values.byName(row['appearance'] as String),
      language: row['language'] as String,
      pinHash: row['pin_hash'] as String?,
      lockOnOpen: row['lock_on_open'] == 1,
      lastBackupAt: lastBackup == null ? null : DateTime.parse(lastBackup),
      tutorialSeen: row['tutorial_seen'] == 1,
    );
  }

  Future<void> setShopName(String name) => _update({'shop_name': name});

  Future<void> setDefaultStaffPercent(int percent) =>
      _update({'default_staff_percent': percent});

  Future<void> setAppearance(AppearanceMode mode) =>
      _update({'appearance': mode.name});

  Future<void> setLastBackupAt(DateTime moment) =>
      _update({'last_backup_at': moment.toUtc().toIso8601String()});

  Future<void> setTutorialSeen(bool seen) =>
      _update({'tutorial_seen': seen ? 1 : 0});

  /// Null removes the PIN. [lockOnOpen] says whether the app also asks for
  /// the PIN when it opens.
  Future<void> setPinHash(String? hash, {bool lockOnOpen = true}) =>
      _update({'pin_hash': hash, 'lock_on_open': lockOnOpen ? 1 : 0});

  Future<void> setLockOnOpen(bool lockOnOpen) =>
      _update({'lock_on_open': lockOnOpen ? 1 : 0});

  Future<void> _update(Map<String, Object?> values) => _db.update('settings', {
    ...values,
    'updated_at': nowIso(),
  }, where: 'id = 1');
}

class StaffRepository {
  StaffRepository(this._db);
  final Database _db;

  /// Everyone, active or not, oldest first.
  Future<List<Staff>> all() async {
    final rows = await _db.query('staff', orderBy: 'created_at, name');
    return [
      for (final row in rows)
        Staff(
          id: row['id'] as String,
          name: row['name'] as String,
          type: StaffType.values.byName(row['type'] as String),
          percentOverride: row['percent_override'] as int?,
          active: row['active'] == 1,
        ),
    ];
  }

  Future<String> create({
    required String name,
    required StaffType type,
    int? percentOverride,
  }) async {
    final id = newId();
    final now = nowIso();
    await _db.insert('staff', {
      'id': id,
      'name': name,
      'type': type.name,
      'percent_override': percentOverride,
      'active': 1,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> update(
    String id, {
    required String name,
    required StaffType type,
    required int? percentOverride,
  }) => _db.update(
    'staff',
    {
      'name': name,
      'type': type.name,
      'percent_override': percentOverride,
      'updated_at': nowIso(),
    },
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> setActive(String id, bool active) =>
      _setActive(_db, 'staff', id, active);
}

class ServiceRepository {
  ServiceRepository(this._db);
  final Database _db;

  Future<List<Service>> all() async {
    final rows = await _db.query('services', orderBy: 'sort_order, name');
    return [
      for (final row in rows)
        Service(
          id: row['id'] as String,
          name: row['name'] as String,
          price: row['price'] as int,
          active: row['active'] == 1,
          sortOrder: row['sort_order'] as int,
        ),
    ];
  }

  /// [price] is in centavos.
  Future<String> create({required String name, required int price}) async {
    final id = newId();
    await _db.insert('services', {
      'id': id,
      'name': name,
      'price': price,
      'active': 1,
      'sort_order': await _nextSortOrder(_db, 'services'),
      'updated_at': nowIso(),
    });
    return id;
  }

  Future<void> update(String id, {required String name, required int price}) =>
      _db.update(
        'services',
        {'name': name, 'price': price, 'updated_at': nowIso()},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> setActive(String id, bool active) =>
      _setActive(_db, 'services', id, active);
}

class ExpenseCategoryRepository {
  ExpenseCategoryRepository(this._db);
  final Database _db;

  Future<List<ExpenseCategory>> all() async {
    final rows = await _db.query(
      'expense_categories',
      orderBy: 'sort_order, name',
    );
    return [
      for (final row in rows)
        ExpenseCategory(
          id: row['id'] as String,
          name: row['name'] as String,
          active: row['active'] == 1,
          sortOrder: row['sort_order'] as int,
        ),
    ];
  }

  Future<String> create({required String name}) async {
    final id = newId();
    await _db.insert('expense_categories', {
      'id': id,
      'name': name,
      'active': 1,
      'sort_order': await _nextSortOrder(_db, 'expense_categories'),
      'updated_at': nowIso(),
    });
    return id;
  }

  Future<void> rename(String id, String name) => _db.update(
    'expense_categories',
    {'name': name, 'updated_at': nowIso()},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> setActive(String id, bool active) =>
      _setActive(_db, 'expense_categories', id, active);
}

Future<void> _setActive(Database db, String table, String id, bool active) =>
    db.update(
      table,
      {'active': active ? 1 : 0, 'updated_at': nowIso()},
      where: 'id = ?',
      whereArgs: [id],
    );

Future<int> _nextSortOrder(Database db, String table) async {
  final rows = await db.rawQuery(
    'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM $table',
  );
  return rows.single['next'] as int;
}
