import 'package:barbershop_app/domain/balance.dart';
import 'package:barbershop_app/domain/day_summary.dart';
import 'package:barbershop_app/domain/sale.dart';
import 'package:barbershop_app/domain/split.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitSale', () {
    void check(int price, int percent, int staff, int shop) {
      final split = splitSale(price: price, staffPercent: percent);
      expect(split.staffShare, staff, reason: '$price at $percent% staff');
      expect(split.shopShare, shop, reason: '$price at $percent% shop');
    }

    test('spec example: P150 at 60/40 gives P90 and P60', () {
      check(15000, 60, 9000, 6000);
    });

    test('exact splits are unchanged', () {
      check(8000, 60, 4800, 3200);
      check(20000, 50, 10000, 10000);
      check(12000, 55, 6600, 5400);
    });

    test('staff share rounds to the nearest peso', () {
      // 85 * 55% = 46.75 -> 47
      check(8500, 55, 4700, 3800);
      // 85 * 65% = 55.25 -> 55
      check(8500, 65, 5500, 3000);
      // 150.50 * 60% = 90.30 -> 90, shop keeps the centavos
      check(15050, 60, 9000, 6050);
    });

    test('exactly 50 centavos rounds up', () {
      // 85 * 50% = 42.50 -> 43
      check(8500, 50, 4300, 4200);
      // 75 * 50% = 37.50 -> 38
      check(7500, 50, 3800, 3700);
    });

    test('0% and 100%', () {
      check(15000, 0, 0, 15000);
      check(15000, 100, 15000, 0);
      check(0, 60, 0, 0);
    });

    test('staff share is never more than the price', () {
      // 150.50 at 100% would round to 151; it is capped at the price.
      check(15050, 100, 15050, 0);
      check(50, 100, 50, 0);
    });

    test('shares always add up to the price and shop is never negative', () {
      for (var price = 0; price <= 40000; price += 250) {
        for (var percent = 0; percent <= 100; percent += 5) {
          final split = splitSale(price: price, staffPercent: percent);
          expect(split.staffShare + split.shopShare, price);
          expect(split.shopShare, greaterThanOrEqualTo(0));
          expect(split.staffShare, greaterThanOrEqualTo(0));
        }
      }
    });

    test('rejects bad input', () {
      expect(() => splitSale(price: -1, staffPercent: 60), throwsArgumentError);
      expect(
        () => splitSale(price: 100, staffPercent: 101),
        throwsArgumentError,
      );
      expect(
        () => splitSale(price: 100, staffPercent: -1),
        throwsArgumentError,
      );
    });
  });

  Sale sale({
    String id = 's',
    String staffId = 'jun',
    int percent = 60,
    int price = 15000,
    int tip = 0,
    bool tipHeld = false,
    PaymentMethod method = PaymentMethod.cash,
    bool voided = false,
  }) {
    final s = Sale.record(
      id: id,
      now: DateTime(2026, 11, 11, 14, 30),
      staffId: staffId,
      staffPercent: percent,
      serviceId: 'haircut',
      serviceName: 'Haircut',
      price: price,
      tip: tip,
      tipHeld: tipHeld,
      paymentMethod: method,
    );
    if (!voided) return s;
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
      note: s.note,
      voided: true,
    );
  }

  group('Sale.record', () {
    test('snapshots the name, price and percent and computes the split', () {
      final s = sale();
      expect(s.businessDate, '2026-11-11');
      expect(s.serviceName, 'Haircut');
      expect(s.price, 15000);
      expect(s.staffPercent, 60);
      expect(s.staffShare, 9000);
      expect(s.shopShare, 6000);
      expect(s.voided, isFalse);
    });

    test('a tip never changes the split', () {
      final s = sale(tip: 5000, tipHeld: true);
      expect(s.staffShare, 9000);
      expect(s.shopShare, 6000);
      expect(s.tip, 5000);
      expect(s.tipHeld, isTrue);
    });

    test('no tip means nothing is held', () {
      expect(sale(tip: 0, tipHeld: true).tipHeld, isFalse);
    });

    test('business date uses the local day', () {
      expect(businessDateOf(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
      expect(businessDateOf(DateTime(2026, 12, 31, 0, 1)), '2026-12-31');
    });
  });

  group('DaySummary', () {
    test('an empty day is all zero', () {
      final day = DaySummary.from(sales: const []);
      expect(day.clients, 0);
      expect(day.sales, 0);
      expect(day.shopNet, 0);
      expect(day.forStaff('jun').clients, 0);
    });

    test('totals, cash and GCash, and per-staff rows', () {
      final day = DaySummary.from(
        sales: [
          sale(id: '1'),
          sale(id: '2', method: PaymentMethod.gcash, price: 20000),
          sale(id: '3', staffId: 'dodong', percent: 50, price: 8000),
        ],
      );
      expect(day.clients, 3);
      expect(day.sales, 43000);
      expect(day.cashSales, 23000);
      expect(day.gcashSales, 20000);
      expect(day.staffShare, 9000 + 12000 + 4000);
      expect(day.shopShare, 6000 + 8000 + 4000);
      expect(day.staffShare + day.shopShare, day.sales);
      expect(day.forStaff('jun').clients, 2);
      expect(day.forStaff('jun').earnings, 21000);
      expect(day.forStaff('dodong').clients, 1);
      expect(day.forStaff('dodong').earnings, 4000);
    });

    test('voided sales are ignored', () {
      final day = DaySummary.from(
        sales: [
          sale(id: '1'),
          sale(id: '2', voided: true),
        ],
      );
      expect(day.clients, 1);
      expect(day.sales, 15000);
      expect(day.forStaff('jun').earnings, 9000);
    });

    test('tips are never shop income', () {
      final day = DaySummary.from(
        sales: [
          sale(id: '1', tip: 5000, tipHeld: true, method: PaymentMethod.gcash),
          sale(id: '2', tip: 2000),
        ],
      );
      expect(day.tips, 7000);
      expect(day.sales, 30000);
      expect(day.shopShare, 12000);
      expect(day.shopNet, 12000);
      expect(day.forStaff('jun').earnings, 18000);
      expect(day.forStaff('jun').tips, 7000);
    });

    test('expenses come out of the shop share only', () {
      final day = DaySummary.from(sales: [sale()], expenses: 2500);
      expect(day.shopNet, 3500);
      expect(day.staffShare, 9000);
      expect(day.forStaff('jun').earnings, 9000);
    });
  });

  group('balance', () {
    test('earnings minus payouts and advances', () {
      const parts = BalanceParts(
        earnings: 90000,
        payouts: 50000,
        advances: 10000,
      );
      expect(parts.balance, 30000);
    });

    test('held tips add to the balance', () {
      expect(const BalanceParts(earnings: 9000, heldTips: 5000).balance, 14000);
    });

    test('an advance larger than earnings gives a negative balance', () {
      expect(
        const BalanceParts(earnings: 9000, advances: 50000).balance,
        -41000,
      );
    });

    test('adjustments can go either way', () {
      expect(
        const BalanceParts(earnings: 9000, adjustments: 1000).balance,
        10000,
      );
      expect(
        const BalanceParts(earnings: 9000, adjustments: -1000).balance,
        8000,
      );
    });

    test('total owed counts positive balances only', () {
      expect(totalOwed([30000, -41000, 14000, 0]), 44000);
      expect(totalOwed([]), 0);
      expect(totalOwed([-500]), 0);
    });
  });
}
