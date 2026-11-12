import 'package:barbershop_app/data/app_database.dart';
import 'package:barbershop_app/data/repositories.dart';
import 'package:barbershop_app/data/sale_repository.dart';
import 'package:barbershop_app/domain/balance.dart';
import 'package:barbershop_app/domain/models.dart';
import 'package:barbershop_app/domain/sale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SaleRepository repo;
  late String jun;
  late String dodong;
  late String haircut;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    repo = SaleRepository(db);
    final staff = StaffRepository(db);
    jun = await staff.create(name: 'Jun', type: StaffType.regular);
    dodong = await staff.create(
      name: 'Dodong',
      type: StaffType.reliever,
      percentOverride: 50,
    );
    haircut = await ServiceRepository(db).create(name: 'Haircut', price: 15000);
  });

  tearDown(() => db.close());

  Sale sale({
    String? staffId,
    int percent = 60,
    int price = 15000,
    int tip = 0,
    bool tipHeld = false,
    PaymentMethod method = PaymentMethod.cash,
    DateTime? now,
    String? serviceId = '',
  }) => Sale.record(
    id: newId(),
    now: now ?? DateTime(2026, 11, 11, 10),
    staffId: staffId ?? jun,
    staffPercent: percent,
    serviceId: serviceId == '' ? haircut : serviceId,
    serviceName: 'Haircut',
    price: price,
    tip: tip,
    tipHeld: tipHeld,
    paymentMethod: method,
  );

  test('a saved sale reads back the same', () async {
    final saved = sale(tip: 5000, tipHeld: true, method: PaymentMethod.gcash);
    await repo.insert(saved);

    final read = (await repo.forDate('2026-11-11')).single;
    expect(read.id, saved.id);
    expect(read.staffId, jun);
    expect(read.serviceId, haircut);
    expect(read.serviceName, 'Haircut');
    expect(read.price, 15000);
    expect(read.staffPercent, 60);
    expect(read.staffShare, 9000);
    expect(read.shopShare, 6000);
    expect(read.tip, 5000);
    expect(read.tipHeld, isTrue);
    expect(read.paymentMethod, PaymentMethod.gcash);
    expect(read.voided, isFalse);
    expect(read.createdAt, saved.createdAt);
  });

  test('an "Other" sale has no service id', () async {
    await repo.insert(sale(serviceId: null));
    expect((await repo.forDate('2026-11-11')).single.serviceId, isNull);
  });

  test('forDate only returns that day', () async {
    await repo.insert(sale());
    await repo.insert(sale(now: DateTime(2026, 11, 12, 9)));
    expect(await repo.forDate('2026-11-11'), hasLength(1));
    expect(await repo.forDate('2026-11-12'), hasLength(1));
    expect(await repo.forDate('2026-11-13'), isEmpty);
  });

  test(
    'changing the price or split later does not change a past sale',
    () async {
      await repo.insert(sale());
      await ServiceRepository(db).update(haircut, name: 'Gupit', price: 20000);
      await SettingsRepository(db).setDefaultStaffPercent(70);

      final read = (await repo.forDate('2026-11-11')).single;
      expect(read.serviceName, 'Haircut');
      expect(read.price, 15000);
      expect(read.staffPercent, 60);
      expect(read.staffShare, 9000);
      expect(read.shopShare, 6000);
    },
  );

  test('void keeps the row and flags it', () async {
    final saved = sale();
    await repo.insert(saved);
    await repo.setVoided(saved.id, true);

    final read = (await repo.forDate('2026-11-11')).single;
    expect(read.voided, isTrue);
    expect(await db.query('sales'), hasLength(1));
  });

  group('balanceParts', () {
    test('sums earnings across days and only held tips', () async {
      await repo.insert(sale());
      await repo.insert(sale(now: DateTime(2026, 11, 12, 9), tip: 2000));
      await repo.insert(
        sale(tip: 5000, tipHeld: true, method: PaymentMethod.gcash),
      );
      await repo.insert(sale(staffId: dodong, percent: 50, price: 8000));

      final parts = await repo.balanceParts();
      expect(parts[jun]!.earnings, 27000);
      expect(parts[jun]!.heldTips, 5000);
      expect(parts[jun]!.balance, 32000);
      expect(parts[dodong]!.balance, 4000);
    });

    test('voided sales are left out', () async {
      final saved = sale();
      await repo.insert(saved);
      await repo.insert(sale());
      await repo.setVoided(saved.id, true);

      expect((await repo.balanceParts())[jun]!.balance, 9000);
    });

    test(
      'payouts, advances and adjustments are applied, voided ones not',
      () async {
        await repo.insert(sale());
        Future<void> pay(String type, int amount, {bool voided = false}) =>
            db.insert('staff_payments', {
              'id': newId(),
              'business_date': '2026-11-11',
              'created_at': nowIso(),
              'updated_at': nowIso(),
              'staff_id': jun,
              'type': type,
              'amount': amount,
              'payment_method': 'cash',
              'voided': voided ? 1 : 0,
            });
        await pay('payout', 4000);
        await pay('advance', 20000);
        await pay('adjustment', -500);
        await pay('payout', 99900, voided: true);

        final parts = (await repo.balanceParts())[jun]!;
        expect(parts.payouts, 4000);
        expect(parts.advances, 20000);
        expect(parts.adjustments, -500);
        expect(parts.balance, 9000 - 4000 - 20000 - 500);
        expect(
          totalOwed((await repo.balanceParts()).values.map((p) => p.balance)),
          0,
        );
      },
    );

    test('staff with no activity are not in the map', () async {
      expect(await repo.balanceParts(), isEmpty);
    });
  });
}
