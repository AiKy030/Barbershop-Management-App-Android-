import 'package:barbershop_app/domain/sale.dart';
import 'package:barbershop_app/domain/tally.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 11, 20, 30);
  final day = DateTime(2026, 11, 9);

  TallyLine line(
    String staff,
    String service,
    int price,
    int count, {
    int percent = 60,
  }) => TallyLine(
    staffId: staff,
    staffPercent: percent,
    serviceId: service,
    serviceName: service,
    price: price,
    count: count,
  );

  List<Sale> build(List<TallyLine> lines) {
    var n = 0;
    return tallySales(
      lines: lines,
      now: now,
      forDate: day,
      batchId: 'batch-1',
      newId: () => 'id-${++n}',
    );
  }

  group('summary', () {
    test('the sample from the design: 32 clients', () {
      // Jun 8 2 1 1, Marlon 7 3 0 1, Rico 6 1 2 0, Dodong 0 0 0 0.
      // Haircut 150, + Shave 200, Shave 80, Kids 120.
      const prices = {'cut': 15000, 'plus': 20000, 'shave': 8000, 'kids': 12000};
      const counts = {
        'jun': [8, 2, 1, 1],
        'marlon': [7, 3, 0, 1],
        'rico': [6, 1, 2, 0],
        'dodong': [0, 0, 0, 0],
      };
      final lines = [
        for (final staff in counts.entries)
          for (var i = 0; i < 4; i++)
            line(
              staff.key,
              prices.keys.elementAt(i),
              prices.values.elementAt(i),
              staff.value[i],
            ),
      ];
      final summary = TallySummary.of(lines);
      expect(summary.clients, 32);
      expect(summary.sales, 483000);
      expect(summary.staffShare, 289800);
      expect(summary.shopShare, 193200);
      expect(summary.staffShare + summary.shopShare, summary.sales);
    });

    test('an empty grid adds up to nothing', () {
      final summary = TallySummary.of([line('jun', 'cut', 15000, 0)]);
      expect(summary.clients, 0);
      expect(summary.sales, 0);
      expect(summary.staffShare, 0);
      expect(summary.shopShare, 0);
    });

    test('each staff member uses his own percent', () {
      final summary = TallySummary.of([
        line('jun', 'cut', 15000, 2),
        line('dodong', 'cut', 15000, 2, percent: 50),
      ]);
      expect(summary.staffShare, 2 * 9000 + 2 * 7500);
      expect(summary.shopShare, 2 * 6000 + 2 * 7500);
    });

    test('rounding is per sale, so it matches the sales saved', () {
      // 60% of ₱85.50 is ₱51.30: ₱51 to the staff member on every sale.
      final lines = [line('jun', 'odd', 8550, 3)];
      final summary = TallySummary.of(lines);
      final sales = build(lines);
      expect(summary.staffShare, 3 * 5100);
      expect(summary.staffShare, sales.fold(0, (s, e) => s + e.staffShare));
      expect(summary.shopShare, sales.fold(0, (s, e) => s + e.shopShare));
      expect(summary.sales, sales.fold(0, (s, e) => s + e.price));
    });
  });

  group('sales from a tally', () {
    test('one sale per client counted', () {
      final sales = build([
        line('jun', 'cut', 15000, 3),
        line('jun', 'shave', 8000, 0),
        line('rico', 'cut', 15000, 2),
      ]);
      expect(sales, hasLength(5));
      expect(sales.where((s) => s.staffId == 'jun'), hasLength(3));
      expect(sales.where((s) => s.staffId == 'rico'), hasLength(2));
      expect(sales.map((s) => s.id).toSet(), hasLength(5));
    });

    test('all on the picked day, typed in now', () {
      final sales = build([line('jun', 'cut', 15000, 4)]);
      expect(sales.every((s) => s.businessDate == '2026-11-09'), isTrue);
      expect(sales.every((s) => s.createdAt == now.toUtc()), isTrue);
    });

    test('all share one batch id', () {
      final sales = build([
        line('jun', 'cut', 15000, 2),
        line('rico', 'kids', 12000, 1),
      ]);
      expect(sales.map((s) => s.batchId).toSet(), {'batch-1'});
    });

    test('cash, no tip, price and percent stored on each sale', () {
      final sale = build([line('dodong', 'cut', 15000, 1, percent: 50)]).single;
      expect(sale.paymentMethod, PaymentMethod.cash);
      expect(sale.tip, 0);
      expect(sale.tipHeld, isFalse);
      expect(sale.price, 15000);
      expect(sale.staffPercent, 50);
      expect(sale.staffShare, 7500);
      expect(sale.shopShare, 7500);
      expect(sale.serviceId, 'cut');
      expect(sale.serviceName, 'cut');
      expect(sale.voided, isFalse);
    });

    test('a count outside 0 to 99 is refused', () {
      expect(() => build([line('jun', 'cut', 15000, 100)]), throwsArgumentError);
      expect(() => build([line('jun', 'cut', 15000, -1)]), throwsArgumentError);
      expect(
        () => TallySummary.of([line('jun', 'cut', 15000, 100)]),
        throwsArgumentError,
      );
      expect(build([line('jun', 'cut', 15000, 99)]), hasLength(99));
    });

    test('a future day is refused', () {
      expect(
        () => tallySales(
          lines: [line('jun', 'cut', 15000, 1)],
          now: now,
          forDate: DateTime(2026, 11, 12),
          batchId: 'b',
          newId: () => 'x',
        ),
        throwsArgumentError,
      );
    });
  });

  group('days that can be picked', () {
    test('today and earlier, never a future day', () {
      expect(isPickableDay(DateTime(2026, 11, 11), now), isTrue);
      expect(isPickableDay(DateTime(2026, 11, 10), now), isTrue);
      expect(isPickableDay(DateTime(2026, 11, 12), now), isFalse);
      expect(isPickableDay(DateTime(2027, 1, 1), now), isFalse);
    });

    test('nothing before 2020', () {
      expect(isPickableDay(DateTime(2020, 1, 1), now), isTrue);
      expect(isPickableDay(DateTime(2019, 12, 31), now), isFalse);
    });
  });

  group('month calendar', () {
    test('November 2026 starts on a Sunday: no blanks', () {
      final cells = monthCells(DateTime(2026, 11, 15));
      expect(cells.first, DateTime(2026, 11, 1));
      expect(cells, hasLength(30));
    });

    test('October 2026 starts on a Thursday: four blanks', () {
      final cells = monthCells(DateTime(2026, 10, 1));
      expect(cells.take(4), everyElement(isNull));
      expect(cells[4], DateTime(2026, 10, 1));
      expect(cells.last, DateTime(2026, 10, 31));
      expect(cells, hasLength(35));
    });

    test('a leap February', () {
      final cells = monthCells(DateTime(2028, 2, 1));
      expect(cells.whereType<DateTime>(), hasLength(29));
    });
  });
}
