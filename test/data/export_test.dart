import 'package:barbershop_app/data/excel_export.dart';
import 'package:barbershop_app/domain/entries.dart';
import 'package:barbershop_app/domain/report.dart';
import 'package:barbershop_app/domain/sale.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var n = 0;

  Sale sale(
    DateTime now, {
    String staff = 'jun',
    int percent = 60,
    int price = 15000,
    int tip = 0,
    DateTime? forDate,
    PaymentMethod method = PaymentMethod.cash,
  }) => Sale.record(
    id: 's${++n}',
    now: now,
    forDate: forDate,
    staffId: staff,
    staffPercent: percent,
    serviceId: null,
    serviceName: 'Haircut',
    price: price,
    tip: tip,
    tipHeld: tip > 0,
    paymentMethod: method,
  );

  StaffPayment pay(
    DateTime now,
    PaymentType type,
    int amount, {
    String staff = 'jun',
    String? note,
  }) => StaffPayment.record(
    id: 'p${++n}',
    now: now,
    staffId: staff,
    type: type,
    amount: amount,
    paymentMethod: type == PaymentType.adjustment ? null : PaymentMethod.cash,
    note: note,
  );

  Expense spend(DateTime now, String category, int amount, {String? note}) =>
      Expense.record(
        id: 'e${++n}',
        now: now,
        category: category,
        amount: amount,
        paymentMethod: PaymentMethod.gcash,
        note: note,
      );

  MonthExport month(
    DateRange range, {
    List<Sale> sales = const [],
    List<StaffPayment> payments = const [],
    List<Expense> expenses = const [],
    Map<String, int> balances = const {},
  }) => MonthExport(
    range: range,
    report: PeriodReport.from(
      range: range,
      sales: sales,
      payments: payments,
      expenses: expenses,
    ),
    sales: sales,
    payments: payments,
    expenses: expenses,
    balancesAtEnd: balances,
  );

  Excel build(DateRange range, List<MonthExport> months) => Excel.decodeBytes(
    buildWorkbook(
      ExportData(
        range: range,
        months: months,
        staffNames: const {'jun': 'Jun', 'dodong': 'Dodong'},
        staffLabel: 'Barber',
      ),
    ),
  );

  /// The sheet as rows of plain values: text as String, numbers as num.
  List<List<Object?>> grid(Excel book, String sheet) => [
    for (final row in book.tables[sheet]!.rows)
      [
        for (final cell in row)
          switch (cell?.value) {
            null => null,
            TextCellValue(:final value) => value.toString(),
            IntCellValue(:final value) => value,
            DoubleCellValue(:final value) => value,
            final other => other.toString(),
          },
      ],
  ];

  /// The row index of the first row whose first cell is [text].
  int find(List<List<Object?>> rows, String text, {int from = 0}) {
    for (var i = from; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][0] == text) return i;
    }
    fail('no row starting with "$text"');
  }

  group('months in a range', () {
    test('one month stays one piece', () {
      final pieces = DateRange.month(DateTime(2026, 11, 12)).months;
      expect(pieces, hasLength(1));
      expect(pieces.single.startKey, '2026-11-01');
      expect(pieces.single.endKey, '2026-11-30');
    });

    test('a range is cut at month ends, keeping only its own days', () {
      final pieces = DateRange(
        DateTime(2026, 11, 20),
        DateTime(2027, 1, 5),
      ).months;
      expect(pieces.map((m) => '${m.startKey}..${m.endKey}'), [
        '2026-11-20..2026-11-30',
        '2026-12-01..2026-12-31',
        '2027-01-01..2027-01-05',
      ]);
    });

    test('a single day', () {
      final pieces = DateRange.day(DateTime(2026, 2, 28)).months;
      expect(pieces.single.isSingleDay, isTrue);
    });
  });

  test('sheet names', () {
    expect(monthSheetName(DateTime(2026, 11, 1)), 'Nov 2026');
    expect(monthSheetName(DateTime(2027, 1, 31)), 'Jan 2027');
  });

  group('one month', () {
    late List<List<Object?>> rows;
    late Excel book;

    setUp(() {
      final range = DateRange.month(DateTime(2026, 11, 1));
      book = build(range, [
        month(
          range,
          sales: [
            sale(DateTime(2026, 11, 10, 10), tip: 5000),
            sale(
              DateTime(2026, 11, 11, 14, 5),
              staff: 'dodong',
              percent: 50,
              method: PaymentMethod.gcash,
            ),
            // Typed on the 12th for the 11th.
            sale(DateTime(2026, 11, 12, 9), forDate: DateTime(2026, 11, 11)),
          ],
          payments: [
            pay(DateTime(2026, 11, 11, 18), PaymentType.payout, 4000),
            pay(
              DateTime(2026, 11, 12, 8),
              PaymentType.advance,
              20000,
              staff: 'dodong',
              note: 'Fare',
            ),
            pay(DateTime(2026, 11, 12, 9), PaymentType.adjustment, -1000),
          ],
          expenses: [
            spend(DateTime(2026, 11, 11, 9), 'Supplies', 25050, note: 'Blades'),
            spend(DateTime(2026, 11, 12, 9), 'Rent', 300000),
          ],
          balances: const {'jun': 10000, 'dodong': -2500},
        ),
      ]);
      rows = grid(book, 'Nov 2026');
    });

    test('is a single sheet named after the month', () {
      expect(book.tables.keys.toList(), ['Nov 2026']);
      expect(rows[0][0], 'November 2026');
      expect(rows[1][0], '2026-11-01 to 2026-11-30');
    });

    test('summary block, amounts as numbers', () {
      final at = find(rows, 'SUMMARY');
      Object? value(String label) => rows[find(rows, label, from: at)][1];
      expect(value('Clients'), 3);
      expect(value('Total sales'), 450);
      expect(value('Cash sales'), 300);
      expect(value('GCash sales'), 150);
      expect(value('Tips'), 50);
      expect(value("Barbers' share"), 90 + 75 + 90);
      expect(value('Shop share'), 60 + 75 + 60);
      expect(value('Expenses'), 3250.5);
      expect(value('Shop net'), 195 - 3250.5);
      expect(value('Payouts made'), 40);
      expect(value('Advances given'), 200);
      expect(value('Total owed to barbers'), 100);
    });

    test('sales, payouts and expenses blocks follow one another', () {
      final sales = find(rows, 'SALES');
      final payouts = find(rows, 'PAYOUTS AND ADVANCES');
      final expenses = find(rows, 'EXPENSES');
      final barbers = find(rows, 'BARBERS');
      expect(find(rows, 'SUMMARY') < sales, isTrue);
      expect(sales < payouts && payouts < expenses, isTrue);
      expect(expenses < barbers, isTrue);
    });

    test('sales block', () {
      final at = find(rows, 'SALES');
      expect(rows[at + 1].take(5), ['Date', 'Time', 'Barber', 'Service', 'Price']);
      expect(rows[at + 1][11], 'Added later');
      final first = rows[at + 2];
      expect(first[0], '2026-11-10');
      expect(first[1], '10:00');
      expect(first[2], 'Jun');
      expect(first[4], 150);
      expect(first[5], 60);
      expect(first[6], 90);
      expect(first[7], 60);
      expect(first[8], 50);
      expect(first[9], 'Cash');
      expect(first[11] ?? '', '');
      expect(rows[at + 3][2], 'Dodong');
      expect(rows[at + 3][9], 'GCash');
      expect(rows[at + 4][0], '2026-11-11');
      expect(rows[at + 4][11], 'Yes');

      final total = rows[at + 5];
      expect(total[0], 'Total');
      expect(total[4], 450);
      expect(total[6], 255);
      expect(total[7], 195);
      expect(total[8], 50);
    });

    test('payouts block: adjustments listed, not in the total', () {
      final at = find(rows, 'PAYOUTS AND ADVANCES');
      expect(rows[at + 1].take(4), ['Date', 'Barber', 'Type', 'Amount']);
      expect(rows[at + 2].take(4), ['2026-11-11', 'Jun', 'Payout', 40]);
      expect(rows[at + 3].take(4), ['2026-11-12', 'Dodong', 'Advance', 200]);
      expect(rows[at + 3][5], 'Fare');
      expect(rows[at + 4].take(4), ['2026-11-12', 'Jun', 'Adjustment', -10]);
      expect(rows[at + 5][0], 'Total paid out');
      expect(rows[at + 5][3], 240);
    });

    test('expenses block', () {
      final at = find(rows, 'EXPENSES');
      expect(rows[at + 1].take(3), ['Date', 'Category', 'Amount']);
      expect(rows[at + 2].take(5), [
        '2026-11-11',
        'Supplies',
        250.5,
        'GCash',
        'Blades',
      ]);
      expect(rows[at + 3][1], 'Rent');
      expect(rows[at + 4][0], 'Total');
      expect(rows[at + 4][2], 3250.5);
    });

    test('barbers block, sorted by name, with balance at end', () {
      final at = find(rows, 'BARBERS');
      expect(rows[at + 1][0], 'Barber');
      expect(rows[at + 1][7], 'Balance at end');
      expect(rows[at + 2][0], 'Dodong');
      expect(rows[at + 2][5], 200);
      expect(rows[at + 2][7], -25);
      expect(rows[at + 3][0], 'Jun');
      expect(rows[at + 3][1], 2);
      expect(rows[at + 3][3], 180);
      expect(rows[at + 3][6], 40);
      expect(rows[at + 3][7], 100);
    });
  });

  test('a month with nothing in a block says None', () {
    final range = DateRange.month(DateTime(2026, 11, 1));
    final rows = grid(
      build(range, [
        month(range, sales: [sale(DateTime(2026, 11, 10, 10))]),
      ]),
      'Nov 2026',
    );
    expect(rows[find(rows, 'PAYOUTS AND ADVANCES') + 1][0], 'None');
    expect(rows[find(rows, 'EXPENSES') + 1][0], 'None');
    expect(rows[find(rows, 'SALES') + 1][0], 'Date');
  });

  group('more than one month', () {
    late Excel book;

    setUp(() {
      final range = DateRange(DateTime(2026, 11, 20), DateTime(2027, 1, 5));
      final pieces = range.months;
      book = build(range, [
        month(
          pieces[0],
          sales: [sale(DateTime(2026, 11, 25, 10))],
          expenses: [spend(DateTime(2026, 11, 26, 9), 'Rent', 5000)],
        ),
        month(
          pieces[1],
          sales: [
            sale(DateTime(2026, 12, 3, 10), price: 20000),
            sale(DateTime(2026, 12, 4, 10), price: 20000),
          ],
          payments: [pay(DateTime(2026, 12, 5, 10), PaymentType.payout, 9000)],
        ),
        month(pieces[2]),
      ]);
    });

    test('a Summary sheet, then one sheet per month in order', () {
      expect(book.tables.keys.toList(), [
        'Summary',
        'Nov 2026',
        'Dec 2026',
        'Jan 2027',
      ]);
    });

    test('each month sheet holds only its own days', () {
      final nov = grid(book, 'Nov 2026');
      final dec = grid(book, 'Dec 2026');
      final jan = grid(book, 'Jan 2027');
      expect(nov[1][0], '2026-11-20 to 2026-11-30');
      expect(jan[1][0], '2027-01-01 to 2027-01-05');
      expect(nov[find(nov, 'SALES') + 2][0], '2026-11-25');
      expect(dec[find(dec, 'SALES') + 2][0], '2026-12-03');
      expect(dec[find(dec, 'SALES') + 3][0], '2026-12-04');
      expect(dec[find(dec, 'SALES') + 4][4], 400);
      expect(jan[find(jan, 'SALES') + 1][0], 'None');
    });

    test('the Summary sheet has one line per month and a total', () {
      final rows = grid(book, 'Summary');
      expect(rows[0][0], '2026-11-20 to 2027-01-05');
      final head = find(rows, 'Month');
      expect(rows[head].take(4), ['Month', 'Clients', 'Sales', "Barbers' share"]);
      expect(rows[head + 1].take(3), ['Nov 2026', 1, 150]);
      expect(rows[head + 2].take(3), ['Dec 2026', 2, 400]);
      expect(rows[head + 3].take(3), ['Jan 2027', 0, 0]);
      final total = rows[head + 4];
      expect(total.take(3), ['Total', 3, 550]);
      expect(total[5], 50); // expenses
      expect(total[7], 90); // payouts
    });
  });
}
