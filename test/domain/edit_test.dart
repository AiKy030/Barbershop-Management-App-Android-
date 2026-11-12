import 'package:barbershop_app/domain/sale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final typed = DateTime(2026, 11, 10, 14, 5);
  final now = DateTime(2026, 11, 12, 9);

  Sale sale({int price = 15000, int percent = 60, int tip = 0}) => Sale.record(
    id: 'sale-1',
    now: typed,
    staffId: 'jun',
    staffPercent: percent,
    serviceId: 'cut',
    serviceName: 'Haircut',
    price: price,
    tip: tip,
    tipHeld: tip > 0,
    paymentMethod: PaymentMethod.cash,
    batchId: 'batch-9',
  );

  test('nothing passed changes nothing', () {
    final original = sale(tip: 2000);
    final same = original.edited(now: now);
    expect(same.sameValuesAs(original), isTrue);
    expect(same.id, original.id);
    expect(same.createdAt, original.createdAt);
  });

  test('a new price is split with the percent stored on the sale', () {
    // Recorded at 60%. Whatever the split is today, an edit keeps 60.
    final edited = sale().edited(now: now, price: 20000);
    expect(edited.price, 20000);
    expect(edited.staffPercent, 60);
    expect(edited.staffShare, 12000);
    expect(edited.shopShare, 8000);
  });

  test('a percent passed for the same staff member is ignored', () {
    final edited = sale().edited(
      now: now,
      staffId: 'jun',
      staffPercent: 40,
      price: 20000,
    );
    expect(edited.staffPercent, 60);
    expect(edited.staffShare, 12000);
  });

  test('the edited split rounds the staff share to the nearest peso', () {
    // 60% of ₱85.50 is ₱51.30, so ₱51 and the shop keeps ₱34.50.
    final edited = sale().edited(now: now, price: 8550);
    expect(edited.staffShare, 5100);
    expect(edited.shopShare, 3450);
    expect(edited.staffShare + edited.shopShare, 8550);
  });

  test('a new staff member brings his own current percent', () {
    final edited = sale().edited(now: now, staffId: 'dodong', staffPercent: 50);
    expect(edited.staffId, 'dodong');
    expect(edited.staffPercent, 50);
    expect(edited.staffShare, 7500);
    expect(edited.shopShare, 7500);
  });

  test('changing the staff member needs his percent', () {
    expect(
      () => sale().edited(now: now, staffId: 'dodong'),
      throwsArgumentError,
    );
  });

  test('a new service changes the stored name and id', () {
    final edited = sale().edited(
      now: now,
      service: (id: 'shave', name: 'Haircut + Shave'),
      price: 20000,
    );
    expect(edited.serviceId, 'shave');
    expect(edited.serviceName, 'Haircut + Shave');
    expect(edited.staffShare, 12000);
  });

  test('a custom service has no id', () {
    final edited = sale().edited(
      now: now,
      service: (id: null, name: 'Beard dye'),
    );
    expect(edited.serviceId, isNull);
    expect(edited.serviceName, 'Beard dye');
  });

  test('a new date moves the sale and keeps when it was typed in', () {
    final original = sale();
    final edited = original.edited(now: now, date: DateTime(2026, 11, 9));
    expect(edited.businessDate, '2026-11-09');
    expect(edited.createdAt, original.createdAt);
    // Moving it to today is allowed.
    expect(
      original.edited(now: now, date: DateTime(2026, 11, 12)).businessDate,
      '2026-11-12',
    );
  });

  test('a future date is refused', () {
    expect(
      () => sale().edited(now: now, date: DateTime(2026, 11, 13)),
      throwsArgumentError,
    );
  });

  test('tip and how it was paid', () {
    final withTip = sale().edited(now: now, tip: 5000, tipHeld: true);
    expect(withTip.tip, 5000);
    expect(withTip.tipHeld, isTrue);
    // No tip can not be a held tip.
    final none = withTip.edited(now: now, tip: 0);
    expect(none.tip, 0);
    expect(none.tipHeld, isFalse);
    expect(() => sale().edited(now: now, tip: -1), throwsArgumentError);
  });

  test('payment method, and what an edit never touches', () {
    final original = sale();
    final edited = original.edited(
      now: now,
      paymentMethod: PaymentMethod.gcash,
    );
    expect(edited.paymentMethod, PaymentMethod.gcash);
    expect(edited.id, original.id);
    expect(edited.batchId, 'batch-9');
    expect(edited.voided, isFalse);
    expect(edited.sameValuesAs(original), isFalse);
  });
}
