import 'dart:io';

import 'package:barbershop_app/data/app_database.dart';
import 'package:barbershop_app/data/backup.dart';
import 'package:barbershop_app/data/repositories.dart';
import 'package:barbershop_app/data/sale_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// `test/fixtures/shop_v1.db` is a real database written by version 1 of
/// the app. It must never be regenerated from newer code.
const _fixture = 'test/fixtures/shop_v1.db';

const _v1Tables = [
  'settings',
  'staff',
  'services',
  'expense_categories',
  'sales',
  'staff_payments',
  'expenses',
  'day_closures',
];

void main() {
  final factory = databaseFactoryFfiNoIsolate;
  late Directory temp;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('shop_migration_test');
  });

  tearDown(() => temp.delete(recursive: true));

  Future<String> copyFixture(String name) async {
    final path = p.join(temp.path, name);
    await File(_fixture).copy(path);
    return path;
  }

  Future<Database> openRaw(String path) => factory.openDatabase(
    path,
    options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
  );

  /// Every row of every version 1 table, keyed by table.
  Future<Map<String, List<Map<String, Object?>>>> dump(Database db) async => {
    for (final table in _v1Tables)
      table: await db.query(table, orderBy: 'rowid'),
  };

  /// Table name to its column names, for every table in the database.
  Future<Map<String, List<String>>> schema(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata' "
      'ORDER BY name',
    );
    return {
      for (final t in tables)
        t['name'] as String: [
          for (final c in await db.rawQuery(
            'PRAGMA table_info(${t['name']})',
          ))
            '${c['name']} ${c['type']} ${c['notnull']} ${c['dflt_value']}',
        ],
    };
  }

  Future<List<String>> indexes(Database db) async => [
    for (final r in await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    ))
      r['name'] as String,
  ];

  test('the fixture really is a version 1 database with records', () async {
    final db = await openRaw(await copyFixture('check.db'));
    expect(await db.getVersion(), 1);
    final rows = await dump(db);
    expect(rows['sales'], hasLength(8));
    expect(rows['staff_payments'], hasLength(4));
    expect(rows['expenses'], hasLength(3));
    expect(rows['day_closures'], hasLength(2));
    expect(rows['settings']!.single['pin_hash'], isNotNull);
    await db.close();
  });

  test('upgrading 1 to 2 keeps every row and every old value', () async {
    final path = await copyFixture('shop.db');
    final raw = await openRaw(path);
    final before = await dump(raw);
    await raw.close();

    final db = await AppDatabase.open(factory: factory, path: path);
    expect(await db.getVersion(), 2);
    final after = await dump(db);
    for (final table in _v1Tables) {
      expect(after[table], hasLength(before[table]!.length), reason: table);
      for (var i = 0; i < before[table]!.length; i++) {
        for (final column in before[table]![i].entries) {
          expect(
            after[table]![i][column.key],
            column.value,
            reason: '$table row $i ${column.key}',
          );
        }
      }
    }
    await db.close();
  });

  test('new columns get their defaults and the log starts empty', () async {
    final db = await AppDatabase.open(
      factory: factory,
      path: await copyFixture('shop.db'),
    );
    final sales = await db.query('sales');
    expect(sales.every((s) => s['batch_id'] == null), isTrue);
    expect((await db.query('settings')).single['lock_on_open'], 1);
    expect(await db.query('day_reopens'), isEmpty);
    // A phone that already had a PIN keeps locking the app as before.
    final settings = await SettingsRepository(db).load();
    expect(settings.pinHash, isNotNull);
    expect(settings.locksApp, isTrue);
    await db.close();
  });

  test('balances are the same before and after the upgrade', () async {
    final path = await copyFixture('shop.db');
    // Version 1 arithmetic, straight from the old file.
    final raw = await openRaw(path);
    final earned = await raw.rawQuery('''
      SELECT staff_id,
             SUM(staff_share) + SUM(CASE WHEN tip_held = 1 THEN tip ELSE 0 END)
               AS total
      FROM sales WHERE voided = 0 GROUP BY staff_id
    ''');
    final paid = await raw.rawQuery('''
      SELECT staff_id,
             SUM(CASE WHEN type = 'adjustment' THEN amount ELSE -amount END)
               AS total
      FROM staff_payments WHERE voided = 0 GROUP BY staff_id
    ''');
    await raw.close();
    final expected = <String, int>{};
    for (final row in [...earned, ...paid]) {
      final id = row['staff_id'] as String;
      expected[id] = (expected[id] ?? 0) + (row['total'] as int);
    }
    expect(expected, isNotEmpty);

    final db = await AppDatabase.open(factory: factory, path: path);
    final parts = await SaleRepository(db).balanceParts();
    expect({
      for (final e in parts.entries) e.key: e.value.balance,
    }, expected);
    await db.close();
  });

  test('a fresh install and an upgraded phone have the same schema', () async {
    final upgraded = await AppDatabase.open(
      factory: factory,
      path: await copyFixture('shop.db'),
    );
    final fresh = await AppDatabase.open(
      factory: factory,
      path: p.join(temp.path, 'fresh.db'),
    );
    expect(await schema(upgraded), await schema(fresh));
    expect(await indexes(upgraded), await indexes(fresh));
    expect((await schema(fresh)).keys, contains('day_reopens'));
    await upgraded.close();
    await fresh.close();
  });

  test('opening a version 2 database again changes nothing', () async {
    final path = await copyFixture('shop.db');
    var db = await AppDatabase.open(factory: factory, path: path);
    final first = await dump(db);
    final firstSchema = await schema(db);
    await db.close();
    db = await AppDatabase.open(factory: factory, path: path);
    expect(await db.getVersion(), 2);
    expect(await dump(db), first);
    expect(await schema(db), firstSchema);
    await db.close();
  });

  test('a copy of the old file is kept before the upgrade', () async {
    final path = await copyFixture('shop.db');
    final original = await File(path).readAsBytes();
    final db = await AppDatabase.open(
      factory: factory,
      path: path,
      keepCopyBeforeUpgrade: true,
    );
    await db.close();
    final copy = File(AppDatabase.copyBeforeUpgradePath(path));
    expect(await copy.exists(), isTrue);
    expect(await copy.readAsBytes(), original);
    final kept = await openRaw(copy.path);
    expect(await kept.getVersion(), 1);
    await kept.close();

    // Opening again, now at version 2, must not overwrite that copy.
    await copy.writeAsString('marker');
    final again = await AppDatabase.open(
      factory: factory,
      path: path,
      keepCopyBeforeUpgrade: true,
    );
    await again.close();
    expect(await copy.readAsString(), 'marker');
  });

  test('no copy is made for a brand new database', () async {
    final path = p.join(temp.path, 'new.db');
    final db = await AppDatabase.open(
      factory: factory,
      path: path,
      keepCopyBeforeUpgrade: true,
    );
    await db.close();
    expect(
      await File(AppDatabase.copyBeforeUpgradePath(path)).exists(),
      isFalse,
    );
  });

  group('restore', () {
    late String livePath;

    setUp(() async {
      livePath = p.join(temp.path, 'live.db');
      final live = await AppDatabase.open(factory: factory, path: livePath);
      await SettingsRepository(live).setShopName('Live Shop');
      await live.close();
    });

    test('a version 1 backup restores cleanly into version 2', () async {
      final backup = await copyFixture('Barbershop_backup_2026-11-11.db');
      expect(await isValidBackup(backup, factory: factory), isTrue);
      final raw = await openRaw(backup);
      final before = await dump(raw);
      await raw.close();

      final staged = await stageRestore(
        backupPath: backup,
        databasePath: livePath,
        factory: factory,
      );
      expect(staged, isNotNull);
      await commitRestore(stagedPath: staged!, databasePath: livePath);
      expect(await File(staged).exists(), isFalse);

      final db = await AppDatabase.open(factory: factory, path: livePath);
      expect(await db.getVersion(), 2);
      expect((await SettingsRepository(db).load()).shopName, 'Fixture Shop');
      final after = await dump(db);
      for (final table in _v1Tables) {
        expect(after[table], hasLength(before[table]!.length), reason: table);
      }
      expect(await db.query('day_reopens'), isEmpty);
      await db.close();

      // The backup file itself is left as it was.
      final untouched = await openRaw(backup);
      expect(await untouched.getVersion(), 1);
      await untouched.close();
    });

    test('a file that is not a backup leaves the records alone', () async {
      final bad = File(p.join(temp.path, 'bad.db'));
      await bad.writeAsString('this is not a database');
      final liveBytes = await File(livePath).readAsBytes();

      final staged = await stageRestore(
        backupPath: bad.path,
        databasePath: livePath,
        factory: factory,
      );
      expect(staged, isNull);
      expect(await File(livePath).readAsBytes(), liveBytes);
      expect(await File('$livePath.restore').exists(), isFalse);
    });

    test('a backup that cannot be upgraded leaves the records alone', () async {
      // Claims to be version 1 but has none of the app's tables.
      final path = p.join(temp.path, 'odd.db');
      final odd = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => db.execute('CREATE TABLE notes (id INTEGER)'),
        ),
      );
      await odd.close();
      final liveBytes = await File(livePath).readAsBytes();

      expect(
        await stageRestore(
          backupPath: path,
          databasePath: livePath,
          factory: factory,
        ),
        isNull,
      );
      expect(await File(livePath).readAsBytes(), liveBytes);
      final db = await AppDatabase.open(factory: factory, path: livePath);
      expect((await SettingsRepository(db).load()).shopName, 'Live Shop');
      await db.close();
    });

    test('a backup from a newer app version is refused', () async {
      final path = await copyFixture('newer.db');
      final db = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await db.setVersion(AppDatabase.schemaVersion + 1);
      await db.close();
      expect(await isValidBackup(path, factory: factory), isFalse);
    });
  });

  test('settings: the PIN and the app lock are separate', () async {
    final db = await AppDatabase.open(
      factory: factory,
      path: inMemoryDatabasePath,
    );
    final repo = SettingsRepository(db);
    expect((await repo.load()).locksApp, isFalse);
    await repo.setPinHash('hash', lockOnOpen: false);
    var s = await repo.load();
    expect(s.pinHash, 'hash');
    expect(s.locksApp, isFalse);
    await repo.setLockOnOpen(true);
    expect((await repo.load()).locksApp, isTrue);
    await repo.setPinHash(null);
    s = await repo.load();
    expect(s.pinHash, isNull);
    expect(s.locksApp, isFalse);
    await db.close();
  });
}
