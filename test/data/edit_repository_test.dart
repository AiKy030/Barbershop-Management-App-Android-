import 'package:barbershop_app/data/app_database.dart';
import 'package:barbershop_app/data/ledger_repositories.dart';
import 'package:barbershop_app/data/records_repository.dart';
import 'package:barbershop_app/data/repositories.dart';
import 'package:barbershop_app/data/sale_repository.dart';
import 'package:barbershop_app/domain/entries.dart';
import 'package:barbershop_app/domain/models.dart';
import 'package:barbershop_app/domain/records.dart';
import 'package:barbershop_app/domain/report.dart';
import 'package:barbershop_app/domain/sale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SaleRepository sales;
  late String jun;
  late String dodong;

  final typed = DateTime(2026, 11, 10, 14, 5);
  final now = DateTime(2026, 11, 12, 9);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    sales = SaleRepository(db);
    final staff = StaffRepository(db);
    jun = await staff.create(name: 'Jun', type: StaffType.regular);
    dodong = await staff.create(
      name: 'Dodong',
      type: StaffType.reliever,
      percentOverride: 50,
    );
  });

  tearDown(() => db.close());

  Future<Sale> saved({String? batchId}) async {
    final sale = Sale.record(
      id: 'sale-1',
      now: typed,
      staffId: jun,
      staffPercent: 60,
      serviceId: null,
      serviceName: 'Haircut',
      price: 15000,
      paymentMethod: PaymentMethod.cash,
      batchId: batchId,
    );
    await sales.insert(sale);
    return sale;
  }

  Future<Sale> stored() async => (await sales.forStaff(jun)).isNotEmpty
      ? (await sales.forStaff(jun)).single
      : (await sales.forStaff(dodong)).single;

  group('editing a sale', () {
    test('the corrected values are saved and updated_at moves on', () async {
      final original = await saved(batchId: 'batch-1');
      final before = (await db.query('sales')).single;
      await Future<void>.delayed(const Duration(milliseconds: 5));

      await sales.update(
        original.edited(
          now: now,
          price: 20000,
          tip: 3000,
          tipHeld: true,
          paymentMethod: PaymentMethod.gcash,
          service: (id: null, name: 'Haircut + Shave'),
        ),
      );

      final after = (await db.query('sales')).single;
      expect(after['price'], 20000);
      expect(after['staff_percent'], 60);
      expect(after['staff_share'], 12000);
      expect(after['shop_share'], 8000);
      expect(after['tip'], 3000);
      expect(after['tip_held'], 1);
      expect(after['payment_method'], 'gcash');
      expect(after['service_name'], 'Haircut + Shave');
      // Not touched by an edit.
      expect(after['id'], before['id']);
      expect(after['created_at'], before['created_at']);
      expect(after['batch_id'], 'batch-1');
      expect(after['voided'], 0);
      expect(after['updated_at'], isNot(before['updated_at']));
      expect(await db.query('sales'), hasLength(1));
    });

    test('balances follow the edit with no extra step', () async {
      final original = await saved();
      expect((await sales.balanceParts())[jun]!.balance, 9000);

      await sales.update(original.edited(now: now, price: 20000));
      expect((await sales.balanceParts())[jun]!.balance, 12000);

      // Moved to another staff member at his own percent.
      final edited = (await stored()).edited(
        now: now,
        staffId: dodong,
        staffPercent: 50,
      );
      await sales.update(edited);
      final parts = await sales.balanceParts();
      expect(parts[jun], isNull);
      expect(parts[dodong]!.balance, 10000);
    });

    test('a changed date moves the sale to that day', () async {
      final original = await saved();
      await sales.update(
        original.edited(now: now, date: DateTime(2026, 11, 9)),
      );
      expect(await sales.forDate('2026-11-10'), isEmpty);
      expect(await sales.forDate('2026-11-09'), hasLength(1));
      // Typed in on the 10th, now on the 9th: it counts as added later.
      final moved = (await sales.forDate('2026-11-09')).single;
      expect(isAddedLater(moved.businessDate, moved.createdAt), isTrue);
    });

    test('undoing an edit puts every old value back, the date too', () async {
      final original = await saved();
      await sales.update(
        original.edited(
          now: now,
          date: DateTime(2026, 11, 9),
          price: 9900,
          staffId: dodong,
          staffPercent: 50,
        ),
      );
      await sales.update(original);
      final back = await stored();
      expect(back.sameValuesAs(original), isTrue);
      expect(back.businessDate, '2026-11-10');
    });
  });

  group('void and restore', () {
    test('a voided sale leaves the Records total and comes back', () async {
      await saved();
      final records = RecordsRepository(db);
      final filter = RecordsFilter(
        tab: RecordsTab.sales,
        range: DateRange(DateTime(2026, 11, 9), DateTime(2026, 11, 12)),
        showVoided: true,
      );
      expect((await records.total(filter)).sum, 15000);

      await sales.setVoided('sale-1', true);
      expect((await records.total(filter)).count, 0);
      expect(await records.sales(filter), hasLength(1));
      expect(await sales.balanceParts(), isEmpty);

      await sales.setVoided('sale-1', false);
      final total = await records.total(filter);
      expect(total.count, 1);
      expect(total.sum, 15000);
      expect((await sales.balanceParts())[jun]!.balance, 9000);
    });
  });

  group('editing an expense', () {
    late ExpenseRepository expenses;

    setUp(() async {
      expenses = ExpenseRepository(db);
      await expenses.insert(
        Expense.record(
          id: 'exp-1',
          now: typed,
          category: 'Supplies',
          amount: 25050,
          paymentMethod: PaymentMethod.cash,
          note: 'Blades',
        ),
      );
    });

    test('without a date the day stays the same', () async {
      await expenses.update(
        'exp-1',
        category: 'Other',
        amount: 30000,
        paymentMethod: PaymentMethod.gcash,
        note: null,
      );
      final e = (await expenses.forRange('2026-11-10', '2026-11-10')).single;
      expect(e.category, 'Other');
      expect(e.amount, 30000);
      expect(e.paymentMethod, PaymentMethod.gcash);
      expect(e.note, isNull);
    });

    test('with a date the expense moves to that day', () async {
      await expenses.update(
        'exp-1',
        category: 'Supplies',
        amount: 25050,
        paymentMethod: PaymentMethod.cash,
        note: 'Blades',
        businessDate: '2026-11-08',
      );
      expect(await expenses.forRange('2026-11-10', '2026-11-10'), isEmpty);
      final e = (await expenses.forRange('2026-11-08', '2026-11-08')).single;
      expect(e.note, 'Blades');
      expect(e.createdAt, typed.toUtc());
    });
  });
}
