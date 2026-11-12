import 'package:sqflite/sqflite.dart';

import '../domain/balance.dart';
import '../domain/sale.dart';
import 'app_database.dart';

class SaleRepository {
  SaleRepository(this._db);
  final Database _db;

  /// Saves every sale or none of them. Used for a past-day tally.
  Future<void> insertBatch(List<Sale> sales) => _db.transaction((txn) async {
    final batch = txn.batch();
    for (final sale in sales) {
      batch.insert('sales', _row(sale));
    }
    await batch.commit(noResult: true);
  });

  /// Voids or brings back every sale saved together in one tally. Sales of
  /// the batch that were changed one by one since are included.
  Future<void> setBatchVoided(String batchId, bool voided) => _db.update(
    'sales',
    {'voided': voided ? 1 : 0, 'updated_at': nowIso()},
    where: 'batch_id = ?',
    whereArgs: [batchId],
  );

  Future<void> insert(Sale sale) => _db.insert('sales', _row(sale));

  Map<String, Object?> _row(Sale sale) => {
    'id': sale.id,
    'business_date': sale.businessDate,
    'created_at': sale.createdAt.toUtc().toIso8601String(),
    'updated_at': nowIso(),
    'staff_id': sale.staffId,
    'service_id': sale.serviceId,
    'service_name': sale.serviceName,
    'price': sale.price,
    'staff_percent': sale.staffPercent,
    'staff_share': sale.staffShare,
    'shop_share': sale.shopShare,
    'tip': sale.tip,
    'tip_held': sale.tipHeld ? 1 : 0,
    'payment_method': sale.paymentMethod.name,
    'note': sale.note,
    'voided': sale.voided ? 1 : 0,
    'batch_id': sale.batchId,
  };

  /// Saves a corrected sale over the one with the same id. The id, the
  /// time it was typed in, the tally batch and the voided flag are left
  /// alone.
  Future<void> update(Sale sale) => _db.update(
    'sales',
    {
      'business_date': sale.businessDate,
      'staff_id': sale.staffId,
      'service_id': sale.serviceId,
      'service_name': sale.serviceName,
      'price': sale.price,
      'staff_percent': sale.staffPercent,
      'staff_share': sale.staffShare,
      'shop_share': sale.shopShare,
      'tip': sale.tip,
      'tip_held': sale.tipHeld ? 1 : 0,
      'payment_method': sale.paymentMethod.name,
      'note': sale.note,
      'updated_at': nowIso(),
    },
    where: 'id = ?',
    whereArgs: [sale.id],
  );

  /// Sales are never deleted. Undo and corrections void them.
  Future<void> setVoided(String id, bool voided) => _db.update(
    'sales',
    {'voided': voided ? 1 : 0, 'updated_at': nowIso()},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Every sale for the day, voided ones included, oldest first.
  Future<List<Sale>> forDate(String businessDate) =>
      forRange(businessDate, businessDate);

  /// Every sale from [startKey] to [endKey] inclusive, oldest first.
  Future<List<Sale>> forRange(String startKey, String endKey) async {
    final rows = await _db.query(
      'sales',
      where: 'business_date BETWEEN ? AND ?',
      whereArgs: [startKey, endKey],
      orderBy: 'created_at',
    );
    return rows.map(fromRow).toList();
  }

  /// Every sale by one staff member, all time, oldest first.
  Future<List<Sale>> forStaff(String staffId) async {
    final rows = await _db.query(
      'sales',
      where: 'staff_id = ?',
      whereArgs: [staffId],
      orderBy: 'created_at',
    );
    return rows.map(fromRow).toList();
  }

  static Sale fromRow(Map<String, Object?> row) => Sale(
    id: row['id'] as String,
    businessDate: row['business_date'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    staffId: row['staff_id'] as String,
    serviceId: row['service_id'] as String?,
    serviceName: row['service_name'] as String,
    price: row['price'] as int,
    staffPercent: row['staff_percent'] as int,
    staffShare: row['staff_share'] as int,
    shopShare: row['shop_share'] as int,
    tip: row['tip'] as int,
    tipHeld: row['tip_held'] == 1,
    paymentMethod: PaymentMethod.values.byName(row['payment_method'] as String),
    note: row['note'] as String?,
    voided: row['voided'] == 1,
    batchId: row['batch_id'] as String?,
  );

  /// Balance inputs per staff id, with voided rows left out. With [upTo]
  /// (a `YYYY-MM-DD` date) only rows on or before that day are counted.
  /// Staff with no sales and no payments are not in the map.
  Future<Map<String, BalanceParts>> balanceParts({String? upTo}) async {
    final dateFilter = upTo == null ? '' : 'AND business_date <= ?';
    final args = upTo == null ? const <Object?>[] : [upTo];
    final sales = await _db.rawQuery('''
      SELECT staff_id,
             SUM(staff_share) AS earnings,
             SUM(CASE WHEN tip_held = 1 THEN tip ELSE 0 END) AS held_tips
      FROM sales WHERE voided = 0 $dateFilter GROUP BY staff_id
    ''', args);
    final payments = await _db.rawQuery('''
      SELECT staff_id, type, SUM(amount) AS total
      FROM staff_payments WHERE voided = 0 $dateFilter
      GROUP BY staff_id, type
    ''', args);

    final earnings = <String, int>{};
    final heldTips = <String, int>{};
    final byType = <String, Map<String, int>>{};
    for (final row in sales) {
      final id = row['staff_id'] as String;
      earnings[id] = row['earnings'] as int;
      heldTips[id] = row['held_tips'] as int;
    }
    for (final row in payments) {
      final id = row['staff_id'] as String;
      (byType[id] ??= {})[row['type'] as String] = row['total'] as int;
    }

    return {
      for (final id in {...earnings.keys, ...byType.keys})
        id: BalanceParts(
          earnings: earnings[id] ?? 0,
          heldTips: heldTips[id] ?? 0,
          payouts: byType[id]?['payout'] ?? 0,
          advances: byType[id]?['advance'] ?? 0,
          adjustments: byType[id]?['adjustment'] ?? 0,
        ),
    };
  }
}
