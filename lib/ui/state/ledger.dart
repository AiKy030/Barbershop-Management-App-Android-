import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../data/excel_export.dart';
import '../../data/ledger_repositories.dart';
import '../../data/records_repository.dart';
import '../../data/sale_repository.dart';
import '../../domain/balance.dart';
import '../../domain/day_summary.dart';
import '../../domain/entries.dart';
import '../../domain/report.dart';
import '../../domain/sale.dart';

/// The shop's money records for the UI: today's totals, balances, this
/// month's expenses and closed days. Every change is saved through the
/// repositories and the totals are recomputed from the saved rows.
class Ledger extends ChangeNotifier {
  Ledger({
    required this._sales,
    required this._payments,
    required this._expenses,
    required this._closures,
    required this.records,
  });

  final SaleRepository _sales;
  final PaymentRepository _payments;
  final ExpenseRepository _expenses;
  final ClosureRepository _closures;

  /// Read-only queries for the Records table.
  final RecordsRepository records;

  DateTime date = DateTime.now();
  DaySummary summary = DaySummary.from(sales: const []);
  CashDrawer drawer = const CashDrawer(
    cashSales: 0,
    cashPayouts: 0,
    cashAdvances: 0,
    cashExpenses: 0,
  );

  /// Balance inputs per staff id. Balances are computed, never stored.
  Map<String, BalanceParts> balances = const {};

  /// Sum of the positive staff balances, in centavos.
  int owedToStaff = 0;

  /// This month's expenses, voided ones left out, newest first.
  List<Expense> monthExpenses = const [];

  /// Closed days by business date.
  Map<String, DayClosure> closures = const {};

  /// Goes up on every reload, so screens know to refresh their own queries.
  int revision = 0;

  String get todayKey => businessDateOf(date);
  bool isClosed(String businessDate) => closures.containsKey(businessDate);
  bool get todayClosed => isClosed(todayKey);
  int balanceOf(String staffId) => balances[staffId]?.balance ?? 0;

  /// Reloads from the database. Also picks up a new day after midnight.
  Future<void> load() async {
    date = DateTime.now();
    final today = todayKey;
    final month = DateRange.month(date);
    final sales = await _sales.forDate(today);
    final payments = await _payments.forRange(today, today);
    monthExpenses = (await _expenses.forRange(
      month.startKey,
      month.endKey,
    )).where((e) => !e.voided).toList();
    final todayExpenses = monthExpenses.where((e) => e.businessDate == today);
    summary = DaySummary.from(
      sales: sales,
      expenses: todayExpenses.fold(0, (sum, e) => sum + e.amount),
    );
    drawer = CashDrawer.from(
      sales: sales,
      payments: payments,
      expenses: todayExpenses,
    );
    balances = await _sales.balanceParts();
    owedToStaff = totalOwed(balances.values.map((p) => p.balance));
    closures = await _closures.all();
    revision++;
    notifyListeners();
  }

  Future<void> addSale(Sale sale) async {
    await _sales.insert(sale);
    await load();
  }

  /// Saves a past-day tally: every sale or none.
  Future<void> addSales(List<Sale> sales) async {
    await _sales.insertBatch(sales);
    await load();
  }

  /// Undo of a tally: voids every sale saved in that batch.
  Future<void> voidBatch(String batchId) async {
    await _sales.setBatchVoided(batchId, true);
    await load();
  }

  Future<void> restoreBatch(String batchId) async {
    await _sales.setBatchVoided(batchId, false);
    await load();
  }

  /// Undo and corrections. The sale is voided, never deleted.
  Future<void> voidSale(String id) async {
    await _sales.setVoided(id, true);
    await load();
  }

  Future<void> addPayment(StaffPayment payment) async {
    await _payments.insert(payment);
    await load();
  }

  Future<void> voidPayment(String id) async {
    await _payments.setVoided(id, true);
    await load();
  }

  Future<void> addExpense(Expense expense) async {
    await _expenses.insert(expense);
    await load();
  }

  /// With [businessDate] the expense also moves to that day.
  Future<void> updateExpense(
    String id, {
    required String category,
    required int amount,
    required PaymentMethod paymentMethod,
    required String? note,
    String? businessDate,
  }) async {
    await _expenses.update(
      id,
      category: category,
      amount: amount,
      paymentMethod: paymentMethod,
      note: note,
      businessDate: businessDate,
    );
    await load();
  }

  /// Saves a corrected sale. Build it with [Sale.edited].
  Future<void> updateSale(Sale sale) async {
    await _sales.update(sale);
    await load();
  }

  Future<void> voidExpense(String id) async {
    await _expenses.setVoided(id, true);
    await load();
  }

  /// Locks today's entries. [cashCounted] is in centavos, or null when the
  /// owner did not count.
  Future<void> closeToday({required int? cashCounted}) =>
      closeDay(todayKey, cashCounted: cashCounted);

  Future<void> reopenToday() => reopenDay(todayKey);

  Future<void> closeDay(
    String businessDate, {
    required int? cashCounted,
  }) async {
    await _closures.close(businessDate, cashCounted: cashCounted);
    await load();
  }

  /// Removes the lock and leaves the day open. Logged as a manual reopen.
  Future<void> reopenDay(String businessDate) async {
    await _closures.reopen(businessDate);
    await load();
  }

  /// Notes in the log that a closed day was changed. The day stays locked.
  Future<void> logReopen(String businessDate, ReopenReason reason) =>
      _closures.logReopen(businessDate, reason);

  /// Brings back a voided sale, payment or expense.
  Future<void> restoreSale(String id) async {
    await _sales.setVoided(id, false);
    await load();
  }

  Future<void> restorePayment(String id) async {
    await _payments.setVoided(id, false);
    await load();
  }

  Future<void> restoreExpense(String id) async {
    await _expenses.setVoided(id, false);
    await load();
  }

  /// One staff member's balance, this week's entries and the carry-over.
  Future<StaffHistory> historyFor(String staffId) async => StaffHistory.from(
    sales: await _sales.forStaff(staffId),
    payments: await _payments.forStaff(staffId),
    weekStart: DateRange.week(DateTime.now()).startKey,
  );

  /// One staff member's sales on one day, voided ones left out.
  Future<List<Sale>> salesFor(String staffId, String businessDate) async =>
      (await _sales.forDate(businessDate))
          .where((s) => s.staffId == staffId && !s.voided)
          .toList();

  Future<PeriodReport> report(DateRange range) async => PeriodReport.from(
    range: range,
    sales: await _sales.forRange(range.startKey, range.endKey),
    payments: await _payments.forRange(range.startKey, range.endKey),
    expenses: await _expenses.forRange(range.startKey, range.endKey),
  );

  /// Everything the Excel file needs for [range], one part per month.
  /// Voided rows are left out.
  Future<ExportData> exportData(
    DateRange range, {
    required Map<String, String> staffNames,
    required String staffLabel,
  }) async {
    int byDay<T>(T a, T b, String Function(T) day, DateTime Function(T) at) {
      final days = day(a).compareTo(day(b));
      return days != 0 ? days : at(a).compareTo(at(b));
    }

    final months = <MonthExport>[];
    for (final month in range.months) {
      final sales =
          (await _sales.forRange(
              month.startKey,
              month.endKey,
            )).where((s) => !s.voided).toList()
            ..sort(
              (a, b) =>
                  byDay(a, b, (s) => s.businessDate, (s) => s.createdAt),
            );
      final payments =
          (await _payments.forRange(
              month.startKey,
              month.endKey,
            )).where((p) => !p.voided).toList()
            ..sort(
              (a, b) =>
                  byDay(a, b, (p) => p.businessDate, (p) => p.createdAt),
            );
      final expenses =
          (await _expenses.forRange(
              month.startKey,
              month.endKey,
            )).where((e) => !e.voided).toList()
            ..sort(
              (a, b) =>
                  byDay(a, b, (e) => e.businessDate, (e) => e.createdAt),
            );
      final parts = await _sales.balanceParts(upTo: month.endKey);
      months.add(
        MonthExport(
          range: month,
          report: PeriodReport.from(
            range: month,
            sales: sales,
            payments: payments,
            expenses: expenses,
          ),
          sales: sales,
          payments: payments,
          expenses: expenses,
          balancesAtEnd: {
            for (final entry in parts.entries) entry.key: entry.value.balance,
          },
        ),
      );
    }
    return ExportData(
      range: range,
      months: months,
      staffNames: staffNames,
      staffLabel: staffLabel,
    );
  }
}

/// Which tab is showing, and which staff member's page is open on the staff
/// tab.
class ShellNav extends ChangeNotifier {
  ShellNav({this.tab = 0, this.staffDetailId});

  static const staffTab = 1;

  int tab;
  String? staffDetailId;

  void selectTab(int index) {
    if (index == tab) {
      // Tapping the staff tab again goes back to the list.
      if (index != staffTab || staffDetailId == null) return;
      staffDetailId = null;
    }
    tab = index;
    notifyListeners();
  }

  void openStaff(String id) {
    tab = staffTab;
    staffDetailId = id;
    notifyListeners();
  }

  void closeStaff() {
    staffDetailId = null;
    notifyListeners();
  }
}

/// Runs [load] against the [Ledger] and runs it again whenever the ledger
/// changes. Keeps showing the last result while the next one loads.
class LedgerQuery<T> extends StatefulWidget {
  const LedgerQuery({
    super.key,
    required this.load,
    required this.builder,
    this.queryKey,
  });

  final Future<T> Function(Ledger ledger) load;
  final Widget Function(BuildContext context, T? data) builder;

  /// Change this to force a reload (for example a different date range).
  final Object? queryKey;

  @override
  State<LedgerQuery<T>> createState() => _LedgerQueryState<T>();
}

class _LedgerQueryState<T> extends State<LedgerQuery<T>> {
  T? _data;
  int? _revision;
  Object? _key;
  int _request = 0;

  void _reloadIfNeeded(Ledger ledger) {
    if (_revision == ledger.revision && _key == widget.queryKey) return;
    _revision = ledger.revision;
    _key = widget.queryKey;
    final request = ++_request;
    widget.load(ledger).then((data) {
      if (mounted && request == _request) setState(() => _data = data);
    });
  }

  @override
  Widget build(BuildContext context) {
    _reloadIfNeeded(context.watch<Ledger>());
    return widget.builder(context, _data);
  }
}
