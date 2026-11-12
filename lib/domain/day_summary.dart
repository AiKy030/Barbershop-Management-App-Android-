/// Totals for one day, computed from that day's sales.
library;

import 'sale.dart';

class StaffDay {
  const StaffDay({
    required this.clients,
    required this.earnings,
    required this.tips,
  });

  static const empty = StaffDay(clients: 0, earnings: 0, tips: 0);

  final int clients;

  /// Sum of the staff shares, in centavos. Tips are not included.
  final int earnings;
  final int tips;
}

class DaySummary {
  const DaySummary({
    required this.clients,
    required this.sales,
    required this.cashSales,
    required this.gcashSales,
    required this.staffShare,
    required this.shopShare,
    required this.tips,
    required this.expenses,
    required this.byStaff,
  });

  /// Voided sales are ignored. [expenses] is the day's expense total in
  /// centavos.
  factory DaySummary.from({required Iterable<Sale> sales, int expenses = 0}) {
    var clients = 0;
    var total = 0;
    var cash = 0;
    var gcash = 0;
    var staffShare = 0;
    var shopShare = 0;
    var tips = 0;
    final byStaff = <String, StaffDay>{};
    for (final sale in sales) {
      if (sale.voided) continue;
      clients++;
      total += sale.price;
      if (sale.paymentMethod == PaymentMethod.cash) {
        cash += sale.price;
      } else {
        gcash += sale.price;
      }
      staffShare += sale.staffShare;
      shopShare += sale.shopShare;
      tips += sale.tip;
      final day = byStaff[sale.staffId] ?? StaffDay.empty;
      byStaff[sale.staffId] = StaffDay(
        clients: day.clients + 1,
        earnings: day.earnings + sale.staffShare,
        tips: day.tips + sale.tip,
      );
    }
    return DaySummary(
      clients: clients,
      sales: total,
      cashSales: cash,
      gcashSales: gcash,
      staffShare: staffShare,
      shopShare: shopShare,
      tips: tips,
      expenses: expenses,
      byStaff: byStaff,
    );
  }

  final int clients;
  final int sales;
  final int cashSales;
  final int gcashSales;
  final int staffShare;
  final int shopShare;

  /// Recorded for totals only. Never part of the shop's money.
  final int tips;
  final int expenses;
  final Map<String, StaffDay> byStaff;

  /// Expenses come out of the shop's share only.
  int get shopNet => shopShare - expenses;

  StaffDay forStaff(String staffId) => byStaff[staffId] ?? StaffDay.empty;
}
