import 'package:barbershop_app/data/app_database.dart';
import 'package:barbershop_app/data/excel_export.dart';
import 'package:barbershop_app/data/ledger_repositories.dart';
import 'package:barbershop_app/data/records_repository.dart';
import 'package:barbershop_app/data/repositories.dart';
import 'package:barbershop_app/data/sale_repository.dart';
import 'package:barbershop_app/domain/entries.dart';
import 'package:barbershop_app/domain/models.dart';
import 'package:barbershop_app/domain/records.dart';
import 'package:barbershop_app/domain/report.dart';
import 'package:barbershop_app/domain/sale.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late RecordsRepository records;
  late SaleRepository sales;
  late String jun;
  late String rico;
  var n = 0;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    n = 0;
    db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    records = RecordsRepository(db);
    sales = SaleRepository(db);
    final staff = StaffRepository(db);
    jun = await staff.create(name: 'Jun', type: StaffType.regular);
    rico = await staff.create(name: 'Rico', type: StaffType.regular);
  });

  tearDown(() => db.close());

  Future<String> sale(
    DateTime now, {
    String? staff,
    String service = 'Haircut',
    int price = 15000,
    DateTime? forDate,
    bool voided = false,
    String? note,
  }) async {
    final id = 's${++n}';
    await sales.insert(
      Sale.record(
        id: id,
        now: now,
        forDate: forDate,
        staffId: staff ?? jun,
        staffPercent: 60,
        serviceId: null,
        serviceName: service,
        price: price,
        paymentMethod: PaymentMethod.cash,
        note: note,
      ),
    );
    if (voided) await sales.setVoided(id, true);
    return id;
  }

  RecordsFilter filter({
    RecordsTab tab = RecordsTab.sales,
    String from = '2026-11-09',
    String to = '2026-11-11',
    String? staffId,
    String? category,
    bool showVoided = false,
    String search = '',
  }) => RecordsFilter(
    tab: tab,
    range: DateRange(parseBusinessDate(from), parseBusinessDate(to)),
    staffId: staffId,
    category: category,
    showVoided: showVoided,
    search: search,
  );

  final d9 = DateTime(2026, 11, 9, 10);
  final d10 = DateTime(2026, 11, 10, 10);
  final d11 = DateTime(2026, 11, 11, 10);

  group('added later', () {
    test('true only when the day is before the day it was typed in', () {
      final typed = DateTime(2026, 11, 11, 15);
      expect(isAddedLater('2026-11-10', typed), isTrue);
      expect(isAddedLater('2026-10-31', typed), isTrue);
      expect(isAddedLater('2026-11-11', typed), isFalse);
      // An entry moved to a later day is not "added later".
      expect(isAddedLater('2026-11-12', typed), isFalse);
    });

    test('uses the local date of created_at, not the UTC date', () {
      // Typed in just after local midnight; created_at is stored in UTC.
      final typed = DateTime(2026, 11, 11, 0, 10);
      expect(isAddedLater('2026-11-11', typed.toUtc()), isFalse);
      expect(isAddedLater('2026-11-10', typed.toUtc()), isTrue);
    });

    test('a backdated sale is added later, a normal sale is not', () async {
      final normal = Sale.record(
        id: 'a',
        now: d11,
        staffId: jun,
        staffPercent: 60,
        serviceId: null,
        serviceName: 'Haircut',
        price: 15000,
        paymentMethod: PaymentMethod.cash,
      );
      final late = Sale.record(
        id: 'b',
        now: d11,
        forDate: DateTime(2026, 11, 9),
        staffId: jun,
        staffPercent: 60,
        serviceId: null,
        serviceName: 'Haircut',
        price: 15000,
        paymentMethod: PaymentMethod.cash,
      );
      expect(isAddedLater(normal.businessDate, normal.createdAt), isFalse);
      expect(isAddedLater(late.businessDate, late.createdAt), isTrue);
    });
  });

  group('filter', () {
    test('default is the last seven days, today included', () {
      final f = RecordsFilter.lastSevenDays(
        RecordsTab.sales,
        DateTime(2026, 11, 12, 20),
      );
      expect(f.range.startKey, '2026-11-06');
      expect(f.range.endKey, '2026-11-12');
      expect(f.range.days, hasLength(7));
      expect(f.showVoided, isFalse);
    });

    test('the default range crosses a month start', () {
      final f = RecordsFilter.lastSevenDays(
        RecordsTab.sales,
        DateTime(2026, 11, 3),
      );
      expect(f.range.startKey, '2026-10-28');
    });

    test('search text that is an amount is read as pesos', () {
      expect(RecordsSearch.parse('150').centavos, 15000);
      expect(RecordsSearch.parse(' 80.50 ').centavos, 8050);
      expect(RecordsSearch.parse('Jun').centavos, isNull);
      expect(RecordsSearch.parse('  ').isEmpty, isTrue);
    });

    test('copyWith can clear the staff filter', () {
      final f = filter(staffId: 'x');
      expect(f.copyWith(showVoided: true).staffId, 'x');
      expect(f.copyWith(staffId: () => null).staffId, isNull);
    });
  });

  group('sales', () {
    test('newest first, by day then by time typed in', () async {
      final a = await sale(d9);
      final b = await sale(d11);
      final c = await sale(d10);
      // Typed on the 11th for the 9th: sorts with the 9th.
      final late = await sale(
        d11.add(const Duration(hours: 2)),
        forDate: DateTime(2026, 11, 9),
      );
      final rows = await records.sales(filter());
      expect(rows.map((s) => s.id), [b, c, late, a]);
    });

    test('sales with the same time keep a steady order', () async {
      final ids = [for (var i = 0; i < 5; i++) await sale(d10)];
      final first = await records.sales(filter());
      final second = await records.sales(filter());
      expect(first.map((s) => s.id), ids.reversed);
      expect(second.map((s) => s.id), first.map((s) => s.id));
    });

    test('date range, staff and voided filters', () async {
      await sale(DateTime(2026, 11, 8, 10));
      await sale(d9);
      await sale(d10, staff: rico);
      await sale(d11, voided: true);
      await sale(DateTime(2026, 11, 12, 10));

      expect(await records.sales(filter()), hasLength(2));
      expect(await records.sales(filter(showVoided: true)), hasLength(3));
      expect(await records.sales(filter(staffId: rico)), hasLength(1));
      expect(
        await records.sales(filter(from: '2026-11-10', to: '2026-11-10')),
        hasLength(1),
      );
      final shown = await records.sales(filter(showVoided: true));
      expect(shown.first.voided, isTrue);
    });

    test('search by staff name, service, note and amount', () async {
      await sale(d9, staff: jun, service: 'Haircut', price: 15000);
      await sale(d9, staff: rico, service: 'Kids Cut', price: 12000);
      await sale(d10, staff: rico, service: 'Shave', price: 8000, note: 'VIP');

      Future<int> count(String text) async =>
          (await records.sales(filter(search: text))).length;
      expect(await count('rico'), 2);
      expect(await count('JUN'), 1);
      expect(await count('cut'), 2);
      expect(await count('vip'), 1);
      expect(await count('120'), 1);
      expect(await count('80'), 1);
      // An amount matches exactly: 15 does not find ₱150.
      expect(await count('15'), 0);
      expect(await count('nothing'), 0);
    });

    test('% and _ in the search are plain characters', () async {
      await sale(d9, service: 'Haircut');
      await sale(d9, service: '50% off cut');
      expect(await records.sales(filter(search: '%')), hasLength(1));
      expect(await records.sales(filter(search: '_')), isEmpty);
    });

    test('pages of 100, with a total for the whole filter', () async {
      for (var i = 0; i < 230; i++) {
        await sale(d10.add(Duration(seconds: i)));
      }
      final page1 = await records.sales(filter());
      final page2 = await records.sales(filter(), offset: 100);
      final page3 = await records.sales(filter(), offset: 200);
      expect(page1, hasLength(100));
      expect(page2, hasLength(100));
      expect(page3, hasLength(30));
      expect(
        {...page1, ...page2, ...page3}.map((s) => s.id).toSet(),
        hasLength(230),
      );
      expect(page1.first.id, 's230');
      expect(page3.last.id, 's1');

      final total = await records.total(filter());
      expect(total.count, 230);
      expect(total.sum, 230 * 15000);
      expect(await records.sales(filter(), limit: null), hasLength(230));
    });
  });

  group('total row', () {
    test('voided rows are never counted, shown or not', () async {
      await sale(d9, price: 15000);
      await sale(d10, price: 20000);
      final voided = await sale(d10, price: 15000);
      await sales.setVoided(voided, true);

      for (final show in [false, true]) {
        final total = await records.total(filter(showVoided: show));
        expect(total.count, 2, reason: 'showVoided $show');
        expect(total.sum, 35000, reason: 'showVoided $show');
      }
      expect(await records.rowCount(filter()), 2);
      expect(await records.rowCount(filter(showVoided: true)), 3);
    });

    test('a restored row is counted again', () async {
      final id = await sale(d9, price: 15000);
      await sales.setVoided(id, true);
      expect((await records.total(filter())).sum, 0);
      await sales.setVoided(id, false);
      final total = await records.total(filter());
      expect(total.count, 1);
      expect(total.sum, 15000);
    });

    test('follows the staff filter and the search', () async {
      await sale(d9, staff: jun, price: 15000);
      await sale(d9, staff: rico, price: 12000);
      expect((await records.total(filter(staffId: rico))).sum, 12000);
      expect((await records.total(filter(search: 'jun'))).sum, 15000);
    });

    test('the sample rows from the design add up to 1,780', () async {
      // Twelve rows, one of them voided (₱150): 1,930 − 150 = 1,780.
      const prices = [150, 200, 120, 80, 150, 350, 150, 200, 150, 150, 80];
      for (final price in prices) {
        await sale(d10, price: price * 100);
      }
      await sale(d10, price: 15000, voided: true);
      final total = await records.total(filter(showVoided: true));
      expect(total.count, 11);
      expect(total.sum, 178000);
    });
  });

  group('payouts tab', () {
    Future<void> pay(
      String id,
      DateTime now,
      PaymentType type,
      int amount, {
      String? staff,
      String? note,
    }) => PaymentRepository(db).insert(
      StaffPayment.record(
        id: id,
        now: now,
        staffId: staff ?? jun,
        type: type,
        amount: amount,
        paymentMethod: type == PaymentType.adjustment
            ? null
            : PaymentMethod.cash,
        note: note,
      ),
    );

    test('payouts, advances and adjustments together', () async {
      await pay('p1', d9, PaymentType.payout, 50000);
      await pay('p2', d10, PaymentType.advance, 20000, staff: rico, note: 'Fare');
      await pay('p3', d11, PaymentType.adjustment, -1000);
      await PaymentRepository(db).setVoided('p1', true);

      final f = filter(tab: RecordsTab.payouts);
      expect((await records.payments(f)).map((p) => p.id), ['p3', 'p2']);
      expect(
        (await records.payments(f.copyWith(showVoided: true))).map((p) => p.id),
        ['p3', 'p2', 'p1'],
      );
      final total = await records.total(f);
      expect(total.count, 2);
      expect(total.sum, 19000);

      expect(await records.payments(f.copyWith(staffId: () => rico)), [
        isA<StaffPayment>().having((p) => p.id, 'id', 'p2'),
      ]);
      expect(await records.payments(f.copyWith(search: 'fare')), hasLength(1));
      expect(await records.payments(f.copyWith(search: 'advance')), hasLength(1));
      // The size of a negative adjustment can be searched.
      expect(await records.payments(f.copyWith(search: '10')), hasLength(1));
    });
  });

  group('expenses tab', () {
    Future<void> spend(
      String id,
      DateTime now,
      String category,
      int amount, {
      String? note,
    }) => ExpenseRepository(db).insert(
      Expense.record(
        id: id,
        now: now,
        category: category,
        amount: amount,
        paymentMethod: PaymentMethod.cash,
        note: note,
      ),
    );

    test('category filter, search and total', () async {
      await spend('e1', d9, 'Rent', 300000);
      await spend('e2', d10, 'Supplies', 45050, note: 'Blades');
      await spend('e3', d11, 'Supplies', 10000);
      await ExpenseRepository(db).setVoided('e3', true);

      final f = filter(tab: RecordsTab.expenses);
      expect((await records.expenses(f)).map((e) => e.id), ['e2', 'e1']);
      expect(await records.expenses(f.copyWith(category: () => 'Rent')), [
        isA<Expense>().having((e) => e.id, 'id', 'e1'),
      ]);
      expect(await records.expenses(f.copyWith(search: 'blade')), hasLength(1));
      expect(await records.expenses(f.copyWith(search: '450.50')), hasLength(1));
      final total = await records.total(f.copyWith(showVoided: true));
      expect(total.count, 2);
      expect(total.sum, 345050);
      expect(await records.usedCategories(), ['Rent', 'Supplies']);
    });
  });

  group('export of the rows shown', () {
    test('file name names the tab and the dates', () {
      expect(
        recordsFileName(filter()),
        'Barbershop_Records_Sales_2026-11-09_to_2026-11-11.xlsx',
      );
      expect(
        recordsFileName(filter(tab: RecordsTab.payouts)),
        'Barbershop_Records_Payouts_2026-11-09_to_2026-11-11.xlsx',
      );
    });

    test('one sheet, amounts as numbers, added later marked', () async {
      await sale(d9, price: 15000);
      await sale(d11, forDate: DateTime(2026, 11, 10), price: 8000);
      final rows = await records.sales(filter(), limit: null);
      final bytes = buildRecordsWorkbook(
        tab: RecordsTab.sales,
        sales: rows,
        staffNames: {jun: 'Jun', rico: 'Rico'},
        staffLabel: 'Barber',
        includeVoided: false,
      );
      final book = Excel.decodeBytes(bytes);
      expect(book.tables.keys, ['Sales']);
      final sheet = book.tables['Sales']!;
      final header = sheet.rows.first.map((c) => c?.value.toString()).toList();
      expect(header, contains('Added later'));
      expect(header, isNot(contains('Voided')));
      expect(sheet.maxRows, 3);

      final priceCol = header.indexOf('Price');
      final laterCol = header.indexOf('Added later');
      final first = sheet.rows[1];
      // A number cell, not text. A whole amount reads back as an integer.
      final price = first[priceCol]!.value;
      expect(price, isNot(isA<TextCellValue>()));
      expect(
        switch (price) {
          IntCellValue(:final value) => value,
          DoubleCellValue(:final value) => value,
          _ => null,
        },
        80,
      );
      expect(first[laterCol]!.value.toString(), 'Yes');
      expect(sheet.rows[2][laterCol]?.value?.toString() ?? '', '');
      expect(first[header.indexOf('Barber')]!.value.toString(), 'Jun');
    });

    test('with voided rows shown, a Voided column is added', () async {
      await sale(d9);
      await sale(d9, voided: true);
      final rows = await records.sales(
        filter(showVoided: true),
        limit: null,
      );
      final book = Excel.decodeBytes(
        buildRecordsWorkbook(
          tab: RecordsTab.sales,
          sales: rows,
          staffNames: {jun: 'Jun'},
          staffLabel: 'Barber',
          includeVoided: true,
        ),
      );
      final sheet = book.tables['Sales']!;
      final header = sheet.rows.first.map((c) => c?.value.toString()).toList();
      final col = header.indexOf('Voided');
      expect(col, greaterThan(0));
      expect(sheet.rows[1][col]!.value.toString(), 'Yes');
      expect(sheet.rows[2][col]?.value?.toString() ?? '', '');
    });
  });
}
