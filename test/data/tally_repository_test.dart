import 'package:barbershop_app/data/app_database.dart';
import 'package:barbershop_app/data/ledger_repositories.dart';
import 'package:barbershop_app/data/records_repository.dart';
import 'package:barbershop_app/data/repositories.dart';
import 'package:barbershop_app/data/sale_repository.dart';
import 'package:barbershop_app/domain/entries.dart';
import 'package:barbershop_app/domain/models.dart';
import 'package:barbershop_app/domain/records.dart';
import 'package:barbershop_app/domain/sale.dart';
import 'package:barbershop_app/domain/tally.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SaleRepository sales;
  late RecordsRepository records;
  late String jun;
  late String rico;

  final now = DateTime(2026, 11, 11, 20, 30);
  final day = DateTime(2026, 11, 9);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    sales = SaleRepository(db);
    records = RecordsRepository(db);
    final staff = StaffRepository(db);
    jun = await staff.create(name: 'Jun', type: StaffType.regular);
    rico = await staff.create(name: 'Rico', type: StaffType.regular);
  });

  tearDown(() => db.close());

  List<Sale> tally(String batchId, Map<String, int> counts) => tallySales(
    lines: [
      for (final entry in counts.entries)
        TallyLine(
          staffId: entry.key,
          staffPercent: 60,
          // An "Other" style line: no service row is needed for the test.
          serviceId: 'cut',
          serviceName: 'Haircut',
          price: 15000,
          count: entry.value,
        ),
    ],
    now: now,
    forDate: day,
    batchId: batchId,
    newId: newId,
  ).map(_withoutServiceId).toList();

  test('a tally saves the right number of sales on the right day', () async {
    await sales.insertBatch(tally('batch-1', {jun: 8, rico: 6}));

    final saved = await sales.forDate('2026-11-09');
    expect(saved, hasLength(14));
    expect(saved.where((s) => s.staffId == jun), hasLength(8));
    expect(saved.map((s) => s.batchId).toSet(), {'batch-1'});
    expect(await sales.forDate('2026-11-11'), isEmpty);
    // The balance follows with no extra step.
    final parts = await sales.balanceParts();
    expect(parts[jun]!.balance, 8 * 9000);
    expect(parts[rico]!.balance, 6 * 9000);
    // Every one of them counts as added later.
    expect(
      saved.every((s) => isAddedLater(s.businessDate, s.createdAt)),
      isTrue,
    );
  });

  test('undo voids exactly that batch and nothing else', () async {
    // A sale entered on its own, an earlier tally, then the tally to undo.
    await sales.insert(
      Sale.record(
        id: 'single',
        now: DateTime(2026, 11, 9, 10),
        staffId: jun,
        staffPercent: 60,
        serviceId: null,
        serviceName: 'Haircut',
        price: 15000,
        paymentMethod: PaymentMethod.cash,
      ),
    );
    await sales.insertBatch(tally('batch-old', {jun: 2}));
    await sales.insertBatch(tally('batch-new', {jun: 3, rico: 1}));

    await sales.setBatchVoided('batch-new', true);

    final all = await sales.forDate('2026-11-09');
    expect(all, hasLength(7));
    expect(
      all.where((s) => s.voided).map((s) => s.batchId).toSet(),
      {'batch-new'},
    );
    expect(all.where((s) => s.voided), hasLength(4));
    expect(all.singleWhere((s) => s.id == 'single').voided, isFalse);
    expect(
      all.where((s) => s.batchId == 'batch-old').every((s) => !s.voided),
      isTrue,
    );
    expect((await sales.balanceParts())[jun]!.balance, 3 * 9000);
    expect((await sales.balanceParts())[rico], isNull);

    // And it can be brought back.
    await sales.setBatchVoided('batch-new', false);
    expect((await sales.forDate('2026-11-09')).every((s) => !s.voided), isTrue);
  });

  test('a tally is saved whole or not at all', () async {
    final good = tally('batch-1', {jun: 2});
    final bad = Sale.record(
      id: good.first.id, // the same id twice breaks the save
      now: now,
      forDate: day,
      staffId: jun,
      staffPercent: 60,
      serviceId: null,
      serviceName: 'Haircut',
      price: 15000,
      paymentMethod: PaymentMethod.cash,
      batchId: 'batch-1',
    );
    await expectLater(sales.insertBatch([...good, bad]), throwsA(anything));
    expect(await sales.forDate('2026-11-09'), isEmpty);
  });

  group('calendar', () {
    setUp(() async {
      await sales.insertBatch(tally('b', {jun: 3}));
      await sales.insert(
        Sale.record(
          id: 'voided',
          now: DateTime(2026, 11, 5, 10),
          staffId: jun,
          staffPercent: 60,
          serviceId: null,
          serviceName: 'Haircut',
          price: 15000,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      await sales.setVoided('voided', true);
      await ExpenseRepository(db).insert(
        Expense.record(
          id: 'e1',
          now: DateTime(2026, 11, 3, 9),
          category: 'Rent',
          amount: 100000,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      await PaymentRepository(db).insert(
        StaffPayment.record(
          id: 'p1',
          now: DateTime(2026, 11, 9, 18),
          staffId: jun,
          type: PaymentType.payout,
          amount: 5000,
          paymentMethod: PaymentMethod.cash,
        ),
      );
    });

    test('days with entries, voided ones left out', () async {
      expect(await records.daysWithEntries('2026-11-01', '2026-11-30'), {
        '2026-11-03',
        '2026-11-09',
      });
      expect(await records.daysWithEntries('2026-11-04', '2026-11-08'), isEmpty);
    });

    test('what is already recorded on a day', () async {
      final nine = await records.entriesOn('2026-11-09');
      expect(nine.clients, 3);
      expect(nine.sales, 45000);
      expect(nine.others, 1);
      expect(nine.isEmpty, isFalse);

      final three = await records.entriesOn('2026-11-03');
      expect(three.clients, 0);
      expect(three.others, 1);
      expect(three.isEmpty, isFalse);

      // Only a voided sale: counts as nothing recorded.
      expect((await records.entriesOn('2026-11-05')).isEmpty, isTrue);
    });
  });
}

/// The test database has no services table rows, so the service id (a
/// foreign key) is dropped. Everything else about the sale is kept.
Sale _withoutServiceId(Sale s) => Sale(
  id: s.id,
  businessDate: s.businessDate,
  createdAt: s.createdAt,
  staffId: s.staffId,
  serviceId: null,
  serviceName: s.serviceName,
  price: s.price,
  staffPercent: s.staffPercent,
  staffShare: s.staffShare,
  shopShare: s.shopShare,
  tip: s.tip,
  tipHeld: s.tipHeld,
  paymentMethod: s.paymentMethod,
  note: s.note,
  voided: s.voided,
  batchId: s.batchId,
);
