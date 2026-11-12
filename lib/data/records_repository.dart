import 'package:sqflite/sqflite.dart';

import '../domain/entries.dart';
import '../domain/records.dart';
import '../domain/sale.dart';
import 'ledger_repositories.dart';
import 'sale_repository.dart';

/// Read-only queries for the Records table: every entry that matches the
/// filters, newest first, a page at a time.
class RecordsRepository {
  RecordsRepository(this._db);
  final Database _db;

  static const int pageSize = 100;

  /// Newest first: by business date, then by when it was typed in. The row
  /// number breaks ties, since the sales of one tally share a time.
  static const _order = 'e.business_date DESC, e.created_at DESC, e.rowid DESC';

  /// [limit] null returns every matching row (used for Export).
  Future<List<Sale>> sales(
    RecordsFilter filter, {
    int? limit = pageSize,
    int offset = 0,
  }) async {
    final where = _Where.sales(filter, countVoided: filter.showVoided);
    final rows = await _db.rawQuery(
      'SELECT e.* FROM sales e JOIN staff st ON st.id = e.staff_id '
      'WHERE ${where.sql} ORDER BY $_order${_page(limit, offset)}',
      where.args,
    );
    return rows.map(SaleRepository.fromRow).toList();
  }

  Future<List<StaffPayment>> payments(
    RecordsFilter filter, {
    int? limit = pageSize,
    int offset = 0,
  }) async {
    final where = _Where.payments(filter, countVoided: filter.showVoided);
    final rows = await _db.rawQuery(
      'SELECT e.* FROM staff_payments e JOIN staff st ON st.id = e.staff_id '
      'WHERE ${where.sql} ORDER BY $_order${_page(limit, offset)}',
      where.args,
    );
    return rows.map(PaymentRepository.fromRow).toList();
  }

  Future<List<Expense>> expenses(
    RecordsFilter filter, {
    int? limit = pageSize,
    int offset = 0,
  }) async {
    final where = _Where.expenses(filter, countVoided: filter.showVoided);
    final rows = await _db.rawQuery(
      'SELECT e.* FROM expenses e '
      'WHERE ${where.sql} ORDER BY $_order${_page(limit, offset)}',
      where.args,
    );
    return rows.map(ExpenseRepository.fromRow).toList();
  }

  /// Count and sum of everything that matches [filter], whether or not it
  /// has been loaded yet. Voided entries are never counted.
  Future<RecordsTotal> total(RecordsFilter filter) async {
    final (from, column, where) = switch (filter.tab) {
      RecordsTab.sales => (
        'sales e JOIN staff st ON st.id = e.staff_id',
        'e.price',
        _Where.sales(filter, countVoided: false),
      ),
      RecordsTab.payouts => (
        'staff_payments e JOIN staff st ON st.id = e.staff_id',
        'e.amount',
        _Where.payments(filter, countVoided: false),
      ),
      RecordsTab.expenses => (
        'expenses e',
        'e.amount',
        _Where.expenses(filter, countVoided: false),
      ),
    };
    final row = (await _db.rawQuery(
      'SELECT COUNT(*) AS n, COALESCE(SUM($column), 0) AS total '
      'FROM $from WHERE ${where.sql}',
      where.args,
    )).single;
    return RecordsTotal(count: row['n'] as int, sum: row['total'] as int);
  }

  /// How many rows the table shows for [filter], voided ones included when
  /// they are being shown.
  Future<int> rowCount(RecordsFilter filter) async {
    final (from, where) = switch (filter.tab) {
      RecordsTab.sales => (
        'sales e JOIN staff st ON st.id = e.staff_id',
        _Where.sales(filter, countVoided: filter.showVoided),
      ),
      RecordsTab.payouts => (
        'staff_payments e JOIN staff st ON st.id = e.staff_id',
        _Where.payments(filter, countVoided: filter.showVoided),
      ),
      RecordsTab.expenses => (
        'expenses e',
        _Where.expenses(filter, countVoided: filter.showVoided),
      ),
    };
    final row = (await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM $from WHERE ${where.sql}',
      where.args,
    )).single;
    return row['n'] as int;
  }

  /// Days from [startKey] to [endKey] that have at least one entry that is
  /// not voided. Used for the dots on the calendar.
  Future<Set<String>> daysWithEntries(String startKey, String endKey) async {
    final rows = await _db.rawQuery(
      '''
      SELECT business_date FROM sales
        WHERE voided = 0 AND business_date BETWEEN ? AND ?
      UNION
      SELECT business_date FROM staff_payments
        WHERE voided = 0 AND business_date BETWEEN ? AND ?
      UNION
      SELECT business_date FROM expenses
        WHERE voided = 0 AND business_date BETWEEN ? AND ?
      ''',
      [startKey, endKey, startKey, endKey, startKey, endKey],
    );
    return {for (final row in rows) row['business_date'] as String};
  }

  /// What is already recorded on one day, voided entries left out.
  Future<DayEntries> entriesOn(String businessDate) async {
    final sales = (await _db.rawQuery(
      'SELECT COUNT(*) AS n, COALESCE(SUM(price), 0) AS total FROM sales '
      'WHERE voided = 0 AND business_date = ?',
      [businessDate],
    )).single;
    final others = (await _db.rawQuery(
      'SELECT (SELECT COUNT(*) FROM staff_payments '
      '          WHERE voided = 0 AND business_date = ?) '
      '     + (SELECT COUNT(*) FROM expenses '
      '          WHERE voided = 0 AND business_date = ?) AS n',
      [businessDate, businessDate],
    )).single;
    return DayEntries(
      clients: sales['n'] as int,
      sales: sales['total'] as int,
      others: others['n'] as int,
    );
  }

  /// Every expense category ever used, for the category filter.
  Future<List<String>> usedCategories() async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT category FROM expenses ORDER BY category',
    );
    return [for (final row in rows) row['category'] as String];
  }

  static String _page(int? limit, int offset) =>
      limit == null ? '' : ' LIMIT $limit OFFSET $offset';
}

/// A WHERE clause and its arguments.
class _Where {
  _Where._(RecordsFilter filter, {required bool countVoided}) {
    _add('e.business_date BETWEEN ? AND ?', [
      filter.range.startKey,
      filter.range.endKey,
    ]);
    if (!countVoided) _add('e.voided = 0');
  }

  factory _Where.sales(RecordsFilter filter, {required bool countVoided}) {
    final where = _Where._(filter, countVoided: countVoided);
    if (filter.staffId != null) where._add('e.staff_id = ?', [filter.staffId]);
    where._search(
      filter,
      textColumns: const ['st.name', 'e.service_name', 'e.note'],
      amountColumn: 'e.price',
    );
    return where;
  }

  factory _Where.payments(RecordsFilter filter, {required bool countVoided}) {
    final where = _Where._(filter, countVoided: countVoided);
    if (filter.staffId != null) where._add('e.staff_id = ?', [filter.staffId]);
    where._search(
      filter,
      textColumns: const ['st.name', 'e.note', 'e.type'],
      // Adjustments can be negative; match on the size of the amount.
      amountColumn: 'ABS(e.amount)',
    );
    return where;
  }

  factory _Where.expenses(RecordsFilter filter, {required bool countVoided}) {
    final where = _Where._(filter, countVoided: countVoided);
    if (filter.category != null) {
      where._add('e.category = ?', [filter.category]);
    }
    where._search(
      filter,
      textColumns: const ['e.category', 'e.note'],
      amountColumn: 'e.amount',
    );
    return where;
  }

  final _parts = <String>[];
  final args = <Object?>[];

  String get sql => _parts.join(' AND ');

  void _add(String sql, [List<Object?> values = const []]) {
    _parts.add(sql);
    args.addAll(values);
  }

  void _search(
    RecordsFilter filter, {
    required List<String> textColumns,
    required String amountColumn,
  }) {
    final search = RecordsSearch.parse(filter.search);
    if (search.isEmpty) return;
    // % and _ are wildcards in LIKE, so they are escaped.
    final escaped = search.text
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final pattern = '%$escaped%';
    final options = [
      for (final column in textColumns) "$column LIKE ? ESCAPE '\\'",
      if (search.centavos != null) '$amountColumn = ?',
    ];
    _add('(${options.join(' OR ')})', [
      for (final _ in textColumns) pattern,
      if (search.centavos != null) search.centavos,
    ]);
  }
}
