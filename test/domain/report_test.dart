import 'package:barbershop_app/domain/entries.dart';
import 'package:barbershop_app/domain/pin.dart';
import 'package:barbershop_app/domain/report.dart';
import 'package:barbershop_app/domain/sale.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;

Sale sale(
  String date, {
  String staff = 'jun',
  int percent = 60,
  int price = 15000,
  int tip = 0,
  bool tipHeld = false,
  PaymentMethod method = PaymentMethod.cash,
  bool voided = false,
}) {
  final s = Sale.record(
    id: 's${_n++}',
    now: parseBusinessDate(date).add(const Duration(hours: 10)),
    staffId: staff,
    staffPercent: percent,
    serviceId: null,
    serviceName: 'Haircut',
    price: price,
    tip: tip,
    tipHeld: tipHeld,
    paymentMethod: method,
  );
  return Sale(
    id: s.id,
    businessDate: s.businessDate,
    createdAt: s.createdAt,
    staffId: s.staffId,
    serviceId: s.serviceId,
    serviceName: s.serviceName,
    price: s.price,
    staffPercent: s.staffPercent,
    staffShare: s.staffShare,
    shopShare: s.shopShare,
    tip: s.tip,
    tipHeld: s.tipHeld,
    paymentMethod: s.paymentMethod,
    note: null,
    voided: voided,
  );
}

StaffPayment pay(
  String date,
  PaymentType type,
  int amount, {
  String staff = 'jun',
  PaymentMethod? method = PaymentMethod.cash,
  bool voided = false,
  int hour = 12,
}) => StaffPayment(
  id: 'p${_n++}',
  businessDate: date,
  createdAt: parseBusinessDate(date).add(Duration(hours: hour)).toUtc(),
  staffId: staff,
  type: type,
  amount: amount,
  paymentMethod: method,
  note: null,
  voided: voided,
);

Expense expense(
  String date,
  int amount, {
  PaymentMethod method = PaymentMethod.cash,
  bool voided = false,
}) => Expense(
  id: 'e${_n++}',
  businessDate: date,
  createdAt: parseBusinessDate(date).toUtc(),
  category: 'Supplies',
  amount: amount,
  paymentMethod: method,
  note: null,
  voided: voided,
);

void main() {
  group('DateRange', () {
    test('week runs Monday to Sunday', () {
      // 2026-11-11 is a Wednesday.
      final week = DateRange.week(DateTime(2026, 11, 11, 15));
      expect(week.startKey, '2026-11-09');
      expect(week.endKey, '2026-11-15');
      expect(week.days, hasLength(7));
      expect(DateRange.week(DateTime(2026, 11, 15)).startKey, '2026-11-09');
      expect(DateRange.week(DateTime(2026, 11, 9)).startKey, '2026-11-09');
    });

    test('month covers the whole month, leap years too', () {
      expect(DateRange.month(DateTime(2026, 11, 11)).endKey, '2026-11-30');
      expect(DateRange.month(DateTime(2028, 2, 10)).endKey, '2028-02-29');
      expect(DateRange.month(DateTime(2026, 2, 10)).days, hasLength(28));
    });

    test('shifting moves by one day, week or month', () {
      final day = DateRange.day(DateTime(2026, 12, 31));
      expect(day.shifted(Period.day, 1).startKey, '2027-01-01');
      final week = DateRange.week(DateTime(2026, 11, 11));
      expect(week.shifted(Period.week, -1).startKey, '2026-11-02');
      final month = DateRange.month(DateTime(2026, 1, 31));
      expect(month.shifted(Period.month, 1).endKey, '2026-02-28');
      expect(month.shifted(Period.month, -1).startKey, '2025-12-01');
    });

    test('containsKey is inclusive', () {
      final week = DateRange.week(DateTime(2026, 11, 11));
      expect(week.containsKey('2026-11-09'), isTrue);
      expect(week.containsKey('2026-11-15'), isTrue);
      expect(week.containsKey('2026-11-08'), isFalse);
      expect(week.containsKey('2026-11-16'), isFalse);
    });

    test('rejects an end before the start', () {
      expect(
        () => DateRange(DateTime(2026, 11, 2), DateTime(2026, 11, 1)),
        throwsArgumentError,
      );
    });
  });

  group('PeriodReport', () {
    final week = DateRange.week(DateTime(2026, 11, 11));

    test('totals only count rows inside the range that are not voided', () {
      final report = PeriodReport.from(
        range: week,
        sales: [
          sale('2026-11-09'),
          sale('2026-11-10', method: PaymentMethod.gcash, price: 20000),
          sale('2026-11-10', staff: 'dodong', percent: 50, price: 8000),
          sale('2026-11-10', voided: true),
          sale('2026-11-08'),
          sale('2026-11-16'),
        ],
        payments: [
          pay('2026-11-10', PaymentType.payout, 5000),
          pay('2026-11-11', PaymentType.advance, 3000, staff: 'dodong'),
          pay('2026-11-11', PaymentType.payout, 9900, voided: true),
          pay('2026-11-02', PaymentType.payout, 7700),
        ],
        expenses: [
          expense('2026-11-09', 2500),
          expense('2026-11-09', 9900, voided: true),
          expense('2026-11-01', 100000),
        ],
      );
      expect(report.totals.clients, 3);
      expect(report.totals.sales, 43000);
      expect(report.totals.cashSales, 23000);
      expect(report.totals.gcashSales, 20000);
      expect(report.totals.staffShare, 9000 + 12000 + 4000);
      expect(report.totals.shopShare, 18000);
      expect(report.totals.expenses, 2500);
      expect(report.totals.shopNet, 15500);
      expect(report.payouts, 5000);
      expect(report.advances, 3000);
      expect(report.salesByDate, {'2026-11-09': 15000, '2026-11-10': 28000});
    });

    test('payouts and advances are not expenses', () {
      final report = PeriodReport.from(
        range: week,
        sales: [sale('2026-11-09')],
        payments: [
          pay('2026-11-09', PaymentType.payout, 9000),
          pay('2026-11-09', PaymentType.advance, 5000),
        ],
        expenses: const [],
      );
      expect(report.totals.shopNet, 6000);
    });

    test('per-staff breakdown', () {
      final report = PeriodReport.from(
        range: week,
        sales: [
          sale('2026-11-09', tip: 2000),
          sale('2026-11-10'),
          sale('2026-11-10', staff: 'dodong', percent: 50, price: 8000),
        ],
        payments: [
          pay('2026-11-10', PaymentType.payout, 5000),
          pay('2026-11-11', PaymentType.advance, 3000, staff: 'rico'),
        ],
        expenses: const [],
      );
      final jun = report.forStaff('jun');
      expect(jun.clients, 2);
      expect(jun.sales, 30000);
      expect(jun.earnings, 18000);
      expect(jun.tips, 2000);
      expect(jun.payouts, 5000);
      expect(jun.advances, 0);
      expect(report.forStaff('dodong').earnings, 4000);
      // A staff member with an advance but no sales still appears.
      expect(report.forStaff('rico').advances, 3000);
      expect(report.forStaff('rico').clients, 0);
      expect(report.forStaff('nobody').clients, 0);
    });
  });

  group('CashDrawer', () {
    test('expected = cash sales - cash payouts - advances - cash expenses', () {
      final drawer = CashDrawer.from(
        sales: [
          sale('2026-11-11', price: 510000),
          sale('2026-11-11', price: 60000, method: PaymentMethod.gcash),
          sale('2026-11-11', price: 99900, voided: true),
        ],
        payments: [
          pay('2026-11-11', PaymentType.payout, 50000),
          pay(
            '2026-11-11',
            PaymentType.payout,
            70000,
            method: PaymentMethod.gcash,
          ),
          pay('2026-11-11', PaymentType.advance, 50000, method: null),
          pay('2026-11-11', PaymentType.adjustment, -9900),
          pay('2026-11-11', PaymentType.payout, 88800, voided: true),
        ],
        expenses: [
          expense('2026-11-11', 25000),
          expense('2026-11-11', 120000, method: PaymentMethod.gcash),
          expense('2026-11-11', 77700, voided: true),
        ],
      );
      expect(drawer.cashSales, 510000);
      expect(drawer.cashPayouts, 50000);
      expect(drawer.cashAdvances, 50000);
      expect(drawer.cashExpenses, 25000);
      expect(drawer.paidOut, 125000);
      expect(drawer.expected, 385000);
    });

    test('matches, short and over', () {
      const drawer = CashDrawer(
        cashSales: 510000,
        cashPayouts: 100000,
        cashAdvances: 0,
        cashExpenses: 25000,
      );
      expect(drawer.difference(385000), 0);
      expect(drawer.difference(380000), -5000);
      expect(drawer.difference(390000), 5000);
    });

    test('a cash tip handed over does not change the drawer', () {
      final drawer = CashDrawer.from(
        sales: [sale('2026-11-11', tip: 5000)],
        payments: const [],
        expenses: const [],
      );
      expect(drawer.expected, 15000);
    });
  });

  group('StaffHistory', () {
    test('this week newest first, older rows carried over', () {
      final history = StaffHistory.from(
        weekStart: '2026-11-09',
        sales: [
          sale('2026-11-02'), // +90 before this week
          sale('2026-11-09'),
          sale('2026-11-09'),
          sale('2026-11-10'),
          sale('2026-11-10', voided: true),
          sale('2026-11-11', tip: 5000, tipHeld: true),
          sale('2026-11-11', tip: 2000),
        ],
        payments: [
          pay('2026-11-03', PaymentType.payout, 4000), // before
          pay('2026-11-09', PaymentType.advance, 30000),
          pay('2026-11-10', PaymentType.payout, 5000, hour: 9),
          pay('2026-11-10', PaymentType.adjustment, -1000, hour: 15),
          pay('2026-11-10', PaymentType.payout, 99900, voided: true),
        ],
      );

      expect(history.carriedOver, 9000 - 4000);
      expect(
        history.entries.map(
          (e) => '${e.businessDate} ${e.kind.name} ${e.amount}',
        ),
        [
          '2026-11-11 heldTips 5000',
          '2026-11-11 earnings 18000',
          '2026-11-10 adjustment -1000',
          '2026-11-10 payout -5000',
          '2026-11-10 earnings 9000',
          '2026-11-09 advance -30000',
          '2026-11-09 earnings 18000',
        ],
      );
      expect(history.entries[1].clients, 2);
      final shown = history.entries.fold(0, (sum, e) => sum + e.amount);
      expect(history.balance, history.carriedOver + shown);
      expect(history.balance, 5000 + 5000 + 18000 - 1000 - 5000 + 9000 - 12000);
    });

    test('nothing recorded gives a zero balance', () {
      final history = StaffHistory.from(
        weekStart: '2026-11-09',
        sales: const [],
        payments: const [],
      );
      expect(history.balance, 0);
      expect(history.carriedOver, 0);
      expect(history.entries, isEmpty);
    });
  });

  group('entries', () {
    test('payouts and advances must be more than zero', () {
      expect(
        () => StaffPayment.record(
          id: 'x',
          now: DateTime(2026, 11, 11),
          staffId: 'jun',
          type: PaymentType.payout,
          amount: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => Expense.record(
          id: 'x',
          now: DateTime(2026, 11, 11),
          category: 'Rent',
          amount: 0,
          paymentMethod: PaymentMethod.cash,
        ),
        throwsArgumentError,
      );
    });

    test('balance effect and blank notes', () {
      final advance = StaffPayment.record(
        id: 'x',
        now: DateTime(2026, 11, 11),
        staffId: 'jun',
        type: PaymentType.advance,
        amount: 50000,
        note: '  ',
      );
      expect(advance.balanceEffect, -50000);
      expect(advance.note, isNull);
      expect(advance.businessDate, '2026-11-11');

      final e = Expense.record(
        id: 'x',
        now: DateTime(2026, 11, 11),
        category: 'Supplies',
        amount: 25000,
        paymentMethod: PaymentMethod.cash,
        note: ' Blades ',
      );
      expect(e.title, 'Blades');
      expect(expense('2026-11-11', 100).title, 'Supplies');
    });
  });

  group('PIN', () {
    test('only four digits are valid', () {
      expect(isValidPin('1234'), isTrue);
      expect(isValidPin('123'), isFalse);
      expect(isValidPin('12345'), isFalse);
      expect(isValidPin('12a4'), isFalse);
    });

    test('hash verifies the right PIN only and never contains it', () {
      final stored = makePinHash('4821', 'salt-1');
      expect(verifyPin('4821', stored), isTrue);
      expect(verifyPin('4822', stored), isFalse);
      expect(stored.contains('4821'), isFalse);
      expect(makePinHash('4821', 'salt-2'), isNot(stored));
      expect(verifyPin('4821', 'garbage'), isFalse);
    });
  });
}
