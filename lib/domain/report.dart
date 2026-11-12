/// Date ranges, period reports, the cash drawer check and staff history.
/// Pure Dart. Voided rows are ignored everywhere.
library;

import 'balance.dart';
import 'day_summary.dart';
import 'entries.dart';
import 'sale.dart';

enum Period { day, week, month }

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Parses a `YYYY-MM-DD` business date.
DateTime parseBusinessDate(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// An inclusive range of whole days.
class DateRange {
  DateRange(DateTime start, DateTime end)
    : start = _dateOnly(start),
      end = _dateOnly(end) {
    if (this.end.isBefore(this.start)) {
      throw ArgumentError('end is before start');
    }
  }

  factory DateRange.day(DateTime d) => DateRange(d, d);

  /// Monday to Sunday.
  factory DateRange.week(DateTime d) {
    final monday = DateTime(d.year, d.month, d.day - (d.weekday - 1));
    return DateRange(
      monday,
      DateTime(monday.year, monday.month, monday.day + 6),
    );
  }

  factory DateRange.month(DateTime d) =>
      DateRange(DateTime(d.year, d.month, 1), DateTime(d.year, d.month + 1, 0));

  factory DateRange.of(Period period, DateTime d) => switch (period) {
    Period.day => DateRange.day(d),
    Period.week => DateRange.week(d),
    Period.month => DateRange.month(d),
  };

  final DateTime start;
  final DateTime end;

  String get startKey => businessDateOf(start);
  String get endKey => businessDateOf(end);
  bool get isSingleDay => start == end;

  bool containsKey(String businessDate) =>
      businessDate.compareTo(startKey) >= 0 &&
      businessDate.compareTo(endKey) <= 0;

  /// Every day in the range, in order.
  List<DateTime> get days => [
    for (
      var d = start;
      !d.isAfter(end);
      d = DateTime(d.year, d.month, d.day + 1)
    )
      d,
  ];

  /// This range cut into calendar months, oldest first. The first and
  /// last pieces cover only the days inside this range.
  List<DateRange> get months {
    final pieces = <DateRange>[];
    var from = start;
    while (!from.isAfter(end)) {
      final monthEnd = DateTime(from.year, from.month + 1, 0);
      pieces.add(DateRange(from, monthEnd.isAfter(end) ? end : monthEnd));
      from = DateTime(from.year, from.month + 1, 1);
    }
    return pieces;
  }

  /// The neighbouring day, week or month. [step] is -1 or 1.
  DateRange shifted(Period period, int step) => switch (period) {
    Period.day => DateRange.day(
      DateTime(start.year, start.month, start.day + step),
    ),
    Period.week => DateRange.week(
      DateTime(start.year, start.month, start.day + 7 * step),
    ),
    Period.month => DateRange.month(
      DateTime(start.year, start.month + step, 1),
    ),
  };
}

class StaffPeriod {
  const StaffPeriod({
    this.clients = 0,
    this.sales = 0,
    this.earnings = 0,
    this.tips = 0,
    this.advances = 0,
    this.payouts = 0,
  });

  final int clients;
  final int sales;
  final int earnings;
  final int tips;
  final int advances;
  final int payouts;
}

/// Totals for a day or a range of days.
class PeriodReport {
  const PeriodReport({
    required this.range,
    required this.totals,
    required this.payouts,
    required this.advances,
    required this.salesByDate,
    required this.byStaff,
  });

  factory PeriodReport.from({
    required DateRange range,
    required Iterable<Sale> sales,
    required Iterable<StaffPayment> payments,
    required Iterable<Expense> expenses,
  }) {
    final inRange = sales
        .where((s) => !s.voided && range.containsKey(s.businessDate))
        .toList();
    final expenseTotal = expenses
        .where((e) => !e.voided && range.containsKey(e.businessDate))
        .fold(0, (sum, e) => sum + e.amount);
    final totals = DaySummary.from(sales: inRange, expenses: expenseTotal);

    final salesByDate = <String, int>{};
    final staffSales = <String, int>{};
    for (final sale in inRange) {
      salesByDate[sale.businessDate] =
          (salesByDate[sale.businessDate] ?? 0) + sale.price;
      staffSales[sale.staffId] = (staffSales[sale.staffId] ?? 0) + sale.price;
    }

    var payouts = 0;
    var advances = 0;
    final staffPayouts = <String, int>{};
    final staffAdvances = <String, int>{};
    for (final p in payments) {
      if (p.voided || !range.containsKey(p.businessDate)) continue;
      if (p.type == PaymentType.payout) {
        payouts += p.amount;
        staffPayouts[p.staffId] = (staffPayouts[p.staffId] ?? 0) + p.amount;
      } else if (p.type == PaymentType.advance) {
        advances += p.amount;
        staffAdvances[p.staffId] = (staffAdvances[p.staffId] ?? 0) + p.amount;
      }
    }

    final ids = {
      ...totals.byStaff.keys,
      ...staffPayouts.keys,
      ...staffAdvances.keys,
    };
    return PeriodReport(
      range: range,
      totals: totals,
      payouts: payouts,
      advances: advances,
      salesByDate: salesByDate,
      byStaff: {
        for (final id in ids)
          id: StaffPeriod(
            clients: totals.forStaff(id).clients,
            sales: staffSales[id] ?? 0,
            earnings: totals.forStaff(id).earnings,
            tips: totals.forStaff(id).tips,
            advances: staffAdvances[id] ?? 0,
            payouts: staffPayouts[id] ?? 0,
          ),
      },
    );
  }

  final DateRange range;

  /// Clients, sales, shares, tips, expenses and shop net for the range.
  final DaySummary totals;
  final int payouts;
  final int advances;

  /// Total sales per business date. Days with no sales are missing.
  final Map<String, int> salesByDate;
  final Map<String, StaffPeriod> byStaff;

  StaffPeriod forStaff(String id) => byStaff[id] ?? const StaffPeriod();
}

/// The cash drawer check for one day.
class CashDrawer {
  const CashDrawer({
    required this.cashSales,
    required this.cashPayouts,
    required this.cashAdvances,
    required this.cashExpenses,
  });

  /// All inputs should be for the same day. Only cash rows count. A payment
  /// with no method recorded is treated as cash.
  factory CashDrawer.from({
    required Iterable<Sale> sales,
    required Iterable<StaffPayment> payments,
    required Iterable<Expense> expenses,
  }) {
    var cashSales = 0;
    var payouts = 0;
    var advances = 0;
    var cashExpenses = 0;
    for (final s in sales) {
      if (!s.voided && s.paymentMethod == PaymentMethod.cash) {
        cashSales += s.price;
      }
    }
    for (final p in payments) {
      if (p.voided || p.paymentMethod == PaymentMethod.gcash) continue;
      if (p.type == PaymentType.payout) payouts += p.amount;
      if (p.type == PaymentType.advance) advances += p.amount;
    }
    for (final e in expenses) {
      if (!e.voided && e.paymentMethod == PaymentMethod.cash) {
        cashExpenses += e.amount;
      }
    }
    return CashDrawer(
      cashSales: cashSales,
      cashPayouts: payouts,
      cashAdvances: advances,
      cashExpenses: cashExpenses,
    );
  }

  final int cashSales;
  final int cashPayouts;
  final int cashAdvances;
  final int cashExpenses;

  int get paidOut => cashPayouts + cashAdvances + cashExpenses;

  /// Should be in drawer = cash sales - cash payouts - cash advances - cash
  /// expenses.
  int get expected => cashSales - paidOut;

  /// Zero means it matches, negative means short, positive means over.
  int difference(int counted) => counted - expected;
}

enum HistoryKind { earnings, heldTips, payout, advance, adjustment }

class HistoryEntry {
  const HistoryEntry({
    required this.kind,
    required this.businessDate,
    required this.amount,
    this.clients = 0,
    this.payment,
  });

  final HistoryKind kind;
  final String businessDate;

  /// Signed effect on the balance, in centavos.
  final int amount;

  /// For earnings: how many clients that day.
  final int clients;

  /// For payouts, advances and adjustments: the row behind this entry.
  final StaffPayment? payment;
}

/// One staff member's page: the current balance, this week's entries newest
/// first, and what was carried over from before this week.
class StaffHistory {
  const StaffHistory({
    required this.balance,
    required this.carriedOver,
    required this.entries,
  });

  /// [sales] and [payments] are every row for this staff member, all time.
  /// [weekStart] is the Monday of the current week as `YYYY-MM-DD`.
  factory StaffHistory.from({
    required Iterable<Sale> sales,
    required Iterable<StaffPayment> payments,
    required String weekStart,
  }) {
    var earningsBefore = 0;
    var tipsBefore = 0;
    var payoutsBefore = 0;
    var advancesBefore = 0;
    var adjustmentsBefore = 0;
    var total = const BalanceParts().balance;

    final earnings = <String, int>{};
    final clients = <String, int>{};
    final heldTips = <String, int>{};
    for (final s in sales) {
      if (s.voided) continue;
      final held = s.tipHeld ? s.tip : 0;
      total += s.staffShare + held;
      if (s.businessDate.compareTo(weekStart) < 0) {
        earningsBefore += s.staffShare;
        tipsBefore += held;
        continue;
      }
      earnings[s.businessDate] = (earnings[s.businessDate] ?? 0) + s.staffShare;
      clients[s.businessDate] = (clients[s.businessDate] ?? 0) + 1;
      if (held > 0) {
        heldTips[s.businessDate] = (heldTips[s.businessDate] ?? 0) + held;
      }
    }

    final thisWeek = <StaffPayment>[];
    for (final p in payments) {
      if (p.voided) continue;
      total += p.balanceEffect;
      if (p.businessDate.compareTo(weekStart) < 0) {
        switch (p.type) {
          case PaymentType.payout:
            payoutsBefore += p.amount;
          case PaymentType.advance:
            advancesBefore += p.amount;
          case PaymentType.adjustment:
            adjustmentsBefore += p.amount;
        }
      } else {
        thisWeek.add(p);
      }
    }
    thisWeek.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final dates = {
      ...earnings.keys,
      ...thisWeek.map((p) => p.businessDate),
    }.toList()..sort((a, b) => b.compareTo(a));

    final entries = <HistoryEntry>[];
    for (final date in dates) {
      for (final p in thisWeek.where((p) => p.businessDate == date)) {
        entries.add(
          HistoryEntry(
            kind: switch (p.type) {
              PaymentType.payout => HistoryKind.payout,
              PaymentType.advance => HistoryKind.advance,
              PaymentType.adjustment => HistoryKind.adjustment,
            },
            businessDate: date,
            amount: p.balanceEffect,
            payment: p,
          ),
        );
      }
      if (heldTips.containsKey(date)) {
        entries.add(
          HistoryEntry(
            kind: HistoryKind.heldTips,
            businessDate: date,
            amount: heldTips[date]!,
          ),
        );
      }
      if (earnings.containsKey(date)) {
        entries.add(
          HistoryEntry(
            kind: HistoryKind.earnings,
            businessDate: date,
            amount: earnings[date]!,
            clients: clients[date]!,
          ),
        );
      }
    }

    return StaffHistory(
      balance: total,
      carriedOver: BalanceParts(
        earnings: earningsBefore,
        heldTips: tipsBefore,
        payouts: payoutsBefore,
        advances: advancesBefore,
        adjustments: adjustmentsBefore,
      ).balance,
      entries: entries,
    );
  }

  final int balance;

  /// Balance from everything before this week.
  final int carriedOver;
  final List<HistoryEntry> entries;
}
