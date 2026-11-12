import 'package:barbershop_app/data/app_database.dart';
import 'package:barbershop_app/data/repositories.dart';
import 'package:barbershop_app/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() => db.close());

  Future<List<Map<String, Object?>>> columns(String table) =>
      db.rawQuery('PRAGMA table_info($table)');

  group('schema', () {
    const tables = [
      'settings',
      'staff',
      'services',
      'expense_categories',
      'sales',
      'staff_payments',
      'expenses',
      'day_closures',
    ];

    test('all tables from the spec exist', () async {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = rows.map((r) => r['name']).toSet();
      expect(names, containsAll(tables));
    });

    test('every table has updated_at', () async {
      for (final table in tables) {
        final names = (await columns(table)).map((c) => c['name']);
        expect(names, contains('updated_at'), reason: table);
      }
    });

    test('money columns are integers', () async {
      const money = {
        'services': ['price'],
        'sales': ['price', 'staff_share', 'shop_share', 'tip'],
        'staff_payments': ['amount'],
        'expenses': ['amount'],
        'day_closures': ['cash_counted'],
      };
      for (final entry in money.entries) {
        final cols = await columns(entry.key);
        for (final name in entry.value) {
          final col = cols.singleWhere((c) => c['name'] == name);
          expect(col['type'], 'INTEGER', reason: '${entry.key}.$name');
        }
      }
    });

    test('no table stores a balance', () async {
      for (final table in tables) {
        final names = (await columns(table)).map((c) => c['name'] as String);
        expect(names.where((n) => n.contains('balance')), isEmpty);
      }
    });

    test('sales snapshot the service name, price and percent', () async {
      final names = (await columns('sales')).map((c) => c['name']);
      expect(
        names,
        containsAll(['service_name', 'price', 'staff_percent', 'voided']),
      );
    });
  });

  group('settings', () {
    test('seeded with the spec defaults', () async {
      final settings = await SettingsRepository(db).load();
      expect(settings.shopName, 'Barbershop');
      expect(settings.staffLabel, 'Barber');
      expect(settings.defaultStaffPercent, 60);
      expect(settings.defaultShopPercent, 40);
      expect(settings.appearance, AppearanceMode.light);
      expect(settings.pinHash, isNull);
      expect(settings.tutorialSeen, isFalse);
    });

    test('updates are saved', () async {
      final repo = SettingsRepository(db);
      await repo.setShopName('Kanto Cuts');
      await repo.setDefaultStaffPercent(55);
      await repo.setAppearance(AppearanceMode.dark);
      final settings = await repo.load();
      expect(settings.shopName, 'Kanto Cuts');
      expect(settings.defaultStaffPercent, 55);
      expect(settings.appearance, AppearanceMode.dark);
    });

    test('there can only be one settings row', () async {
      expect(
        () => db.insert('settings', {
          'id': 2,
          'shop_name': 'x',
          'staff_label': 'x',
          'default_staff_percent': 60,
          'appearance': 'system',
          'language': 'en',
          'updated_at': nowIso(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('expense categories', () {
    test('seeded with the five defaults in order', () async {
      final all = await ExpenseCategoryRepository(db).all();
      expect(all.map((c) => c.name), [
        'Rent',
        'Electricity',
        'Water',
        'Supplies',
        'Other',
      ]);
      expect(all.every((c) => c.active), isTrue);
    });

    test('new ones go last, and can be renamed and archived', () async {
      final repo = ExpenseCategoryRepository(db);
      final id = await repo.create(name: 'Internet');
      expect((await repo.all()).last.name, 'Internet');

      await repo.rename(id, 'Wifi');
      await repo.setActive(id, false);
      final wifi = (await repo.all()).singleWhere((c) => c.id == id);
      expect(wifi.name, 'Wifi');
      expect(wifi.active, isFalse);
    });
  });

  group('services', () {
    test('price is stored in centavos', () async {
      final repo = ServiceRepository(db);
      final id = await repo.create(name: 'Haircut', price: 15000);
      final row = (await db.query(
        'services',
        where: 'id = ?',
        whereArgs: [id],
      )).single;
      expect(row['price'], 15000);
      expect(id, hasLength(36));
    });

    test('edit and archive keep the row', () async {
      final repo = ServiceRepository(db);
      final id = await repo.create(name: 'Haircut', price: 15000);
      await repo.create(name: 'Shave', price: 8000);

      await repo.update(id, name: 'Haircut', price: 18000);
      await repo.setActive(id, false);

      final all = await repo.all();
      expect(all.map((s) => s.name), ['Haircut', 'Shave']);
      expect(all.first.price, 18000);
      expect(all.first.active, isFalse);

      await repo.setActive(id, true);
      expect((await repo.all()).first.active, isTrue);
    });
  });

  group('staff', () {
    test('percent override is optional', () async {
      final repo = StaffRepository(db);
      await repo.create(name: 'Jun', type: StaffType.regular);
      await repo.create(
        name: 'Dodong',
        type: StaffType.reliever,
        percentOverride: 50,
      );

      final all = await repo.all();
      final jun = all.singleWhere((s) => s.name == 'Jun');
      final dodong = all.singleWhere((s) => s.name == 'Dodong');
      expect(jun.percentOverride, isNull);
      expect(jun.effectivePercent(60), 60);
      expect(dodong.type, StaffType.reliever);
      expect(dodong.effectivePercent(60), 50);
    });

    test('edit and mark inactive keep the row', () async {
      final repo = StaffRepository(db);
      final id = await repo.create(name: 'Rico', type: StaffType.regular);
      await repo.update(
        id,
        name: 'Rico M.',
        type: StaffType.regular,
        percentOverride: 65,
      );
      await repo.setActive(id, false);

      final rico = (await repo.all()).single;
      expect(rico.name, 'Rico M.');
      expect(rico.percentOverride, 65);
      expect(rico.active, isFalse);
    });

    test('percent outside 0 to 100 is rejected', () async {
      expect(
        () => StaffRepository(db)
            .create(name: 'X', type: StaffType.regular, percentOverride: 120),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
