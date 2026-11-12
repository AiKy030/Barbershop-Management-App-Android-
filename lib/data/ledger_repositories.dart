import 'package:sqflite/sqflite.dart';

import '../domain/entries.dart';
import '../domain/sale.dart';
import 'app_database.dart';

PaymentMethod? _method(Object? value) =>
    value == null ? null : PaymentMethod.values.byName(value as String);

class PaymentRepository {
  PaymentRepository(this._db);
  final Database _db;

  Future<void> insert(StaffPayment p) => _db.insert('staff_payments', {
    'id': p.id,
    'business_date': p.businessDate,
    'created_at': p.createdAt.toUtc().toIso8601String(),
    'updated_at': nowIso(),
    'staff_id': p.staffId,
    'type': p.type.name,
    'amount': p.amount,
    'payment_method': p.paymentMethod?.name,
    'note': p.note,
    'voided': p.voided ? 1 : 0,
  });

  Future<void> setVoided(String id, bool voided) => _db.update(
    'staff_payments',
    {'voided': voided ? 1 : 0, 'updated_at': nowIso()},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<List<StaffPayment>> forStaff(String staffId) =>
      _query('staff_id = ?', [staffId]);

  Future<List<StaffPayment>> forRange(String startKey, String endKey) =>
      _query('business_date BETWEEN ? AND ?', [startKey, endKey]);

  Future<List<StaffPayment>> _query(String where, List<Object?> args) async {
    final rows = await _db.query(
      'staff_payments',
      where: where,
      whereArgs: args,
      orderBy: 'created_at',
    );
    return rows.map(fromRow).toList();
  }

  static StaffPayment fromRow(Map<String, Object?> row) => StaffPayment(
    id: row['id'] as String,
    businessDate: row['business_date'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    staffId: row['staff_id'] as String,
    type: PaymentType.values.byName(row['type'] as String),
    amount: row['amount'] as int,
    paymentMethod: _method(row['payment_method']),
    note: row['note'] as String?,
    voided: row['voided'] == 1,
  );
}

class ExpenseRepository {
  ExpenseRepository(this._db);
  final Database _db;

  Future<void> insert(Expense e) => _db.insert('expenses', {
    'id': e.id,
    'business_date': e.businessDate,
    'created_at': e.createdAt.toUtc().toIso8601String(),
    'updated_at': nowIso(),
    'category': e.category,
    'amount': e.amount,
    'payment_method': e.paymentMethod.name,
    'note': e.note,
    'voided': e.voided ? 1 : 0,
  });

  /// Changes what was recorded. With [businessDate] the expense also moves
  /// to that day; without it the date stays the same.
  Future<void> update(
    String id, {
    required String category,
    required int amount,
    required PaymentMethod paymentMethod,
    required String? note,
    String? businessDate,
  }) => _db.update(
    'expenses',
    {
      'business_date': ?businessDate,
      'category': category,
      'amount': amount,
      'payment_method': paymentMethod.name,
      'note': note,
      'updated_at': nowIso(),
    },
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> setVoided(String id, bool voided) => _db.update(
    'expenses',
    {'voided': voided ? 1 : 0, 'updated_at': nowIso()},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Every expense in the range, voided ones included, newest first.
  Future<List<Expense>> forRange(String startKey, String endKey) async {
    final rows = await _db.query(
      'expenses',
      where: 'business_date BETWEEN ? AND ?',
      whereArgs: [startKey, endKey],
      orderBy: 'business_date DESC, created_at DESC',
    );
    return rows.map(fromRow).toList();
  }

  static Expense fromRow(Map<String, Object?> row) => Expense(
    id: row['id'] as String,
    businessDate: row['business_date'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    category: row['category'] as String,
    amount: row['amount'] as int,
    paymentMethod: _method(row['payment_method'])!,
    note: row['note'] as String?,
    voided: row['voided'] == 1,
  );
}

class ClosureRepository {
  ClosureRepository(this._db);
  final Database _db;

  /// Every closed day, keyed by business date.
  Future<Map<String, DayClosure>> all() async {
    final rows = await _db.query('day_closures');
    return {
      for (final row in rows)
        row['business_date'] as String: DayClosure(
          businessDate: row['business_date'] as String,
          closedAt: DateTime.parse(row['closed_at'] as String),
          cashCounted: row['cash_counted'] as int?,
        ),
    };
  }

  /// Locks the day. Closing an already closed day replaces the count.
  Future<void> close(String businessDate, {required int? cashCounted}) =>
      _db.insert('day_closures', {
        'business_date': businessDate,
        'closed_at': nowIso(),
        'cash_counted': cashCounted,
        'updated_at': nowIso(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  /// A row means the day is locked, so reopening removes the row. The
  /// reopen is logged. Reopening a day that is not closed does nothing.
  Future<void> reopen(String businessDate) => _db.transaction((txn) async {
    final removed = await txn.delete(
      'day_closures',
      where: 'business_date = ?',
      whereArgs: [businessDate],
    );
    if (removed > 0) await _log(txn, businessDate, ReopenReason.manual);
  });

  /// Records that a closed day was opened up for one change and locked
  /// again. This is the only place that writes the log, apart from
  /// [reopen].
  Future<void> logReopen(String businessDate, ReopenReason reason) =>
      _log(_db, businessDate, reason);

  Future<void> _log(
    DatabaseExecutor db,
    String businessDate,
    ReopenReason reason,
  ) {
    final now = nowIso();
    return db.insert('day_reopens', {
      'id': newId(),
      'business_date': businessDate,
      'reopened_at': now,
      'reason': reason.code,
      'updated_at': now,
    });
  }

  /// The log for one day, oldest first.
  Future<List<({DateTime at, String reason})>> reopens(
    String businessDate,
  ) async {
    final rows = await _db.query(
      'day_reopens',
      where: 'business_date = ?',
      whereArgs: [businessDate],
      orderBy: 'reopened_at, rowid',
    );
    return [
      for (final row in rows)
        (
          at: DateTime.parse(row['reopened_at'] as String),
          reason: row['reason'] as String,
        ),
    ];
  }
}
