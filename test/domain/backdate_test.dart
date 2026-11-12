import 'package:barbershop_app/domain/entries.dart';
import 'package:barbershop_app/domain/sale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 12, 15, 30);

  Sale sale({DateTime? forDate}) => Sale.record(
    id: 's',
    now: now,
    forDate: forDate,
    staffId: 'jun',
    staffPercent: 60,
    serviceId: null,
    serviceName: 'Haircut',
    price: 15000,
    tip: 2000,
    tipHeld: true,
    paymentMethod: PaymentMethod.gcash,
  );

  test('with no date the entry is for the day it was typed in', () {
    expect(entryDateOf(now, null), '2026-11-12');
    expect(sale().businessDate, '2026-11-12');
  });

  test('a backdated sale changes the day and nothing else', () {
    final normal = sale();
    final back = sale(forDate: DateTime(2026, 11, 3));
    expect(back.businessDate, '2026-11-03');
    expect(back.createdAt, normal.createdAt);
    expect(back.price, normal.price);
    expect(back.staffPercent, normal.staffPercent);
    expect(back.staffShare, normal.staffShare);
    expect(back.shopShare, normal.shopShare);
    expect(back.tip, normal.tip);
    expect(back.tipHeld, normal.tipHeld);
  });

  test('backdating works across a month and a year', () {
    expect(entryDateOf(now, DateTime(2026, 10, 31)), '2026-10-31');
    expect(entryDateOf(now, DateTime(2025, 12, 31)), '2025-12-31');
  });

  test('today, at any time of day, is allowed', () {
    expect(entryDateOf(now, DateTime(2026, 11, 12)), '2026-11-12');
    expect(entryDateOf(now, DateTime(2026, 11, 12, 23, 59)), '2026-11-12');
  });

  test('a future day is refused', () {
    expect(() => entryDateOf(now, DateTime(2026, 11, 13)), throwsArgumentError);
    expect(() => sale(forDate: DateTime(2026, 11, 13)), throwsArgumentError);
  });

  test('payments and expenses can be backdated', () {
    final payout = StaffPayment.record(
      id: 'p',
      now: now,
      forDate: DateTime(2026, 11, 10),
      staffId: 'jun',
      type: PaymentType.payout,
      amount: 50000,
      paymentMethod: PaymentMethod.cash,
    );
    expect(payout.businessDate, '2026-11-10');
    expect(payout.createdAt, now.toUtc());
    expect(payout.balanceEffect, -50000);

    final expense = Expense.record(
      id: 'e',
      now: now,
      forDate: DateTime(2026, 11, 10),
      category: 'Supplies',
      amount: 25000,
      paymentMethod: PaymentMethod.cash,
    );
    expect(expense.businessDate, '2026-11-10');
    expect(expense.createdAt, now.toUtc());

    expect(
      () => StaffPayment.record(
        id: 'p',
        now: now,
        forDate: DateTime(2026, 11, 13),
        staffId: 'jun',
        type: PaymentType.advance,
        amount: 100,
      ),
      throwsArgumentError,
    );
    expect(
      () => Expense.record(
        id: 'e',
        now: now,
        forDate: DateTime(2026, 11, 13),
        category: 'Rent',
        amount: 100,
        paymentMethod: PaymentMethod.cash,
      ),
      throwsArgumentError,
    );
  });
}
