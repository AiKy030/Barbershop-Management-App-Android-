import 'package:sqflite/sqflite.dart';

import '../domain/entries.dart';
import '../domain/models.dart';
import '../domain/sale.dart';
import 'app_database.dart';
import 'ledger_repositories.dart';
import 'repositories.dart';
import 'sale_repository.dart';

/// The tutorial's sample shop. It lives in memory only and is thrown away
/// when closed, so it never reads or writes the owner's real records.
class DemoShop {
  DemoShop._(this.db, this.featuredStaffId);

  final Database db;

  /// The staff member whose page the tutorial opens (Marlon).
  final String featuredStaffId;

  static Future<DemoShop> open() async {
    final db = await AppDatabase.open(
      path: inMemoryDatabasePath,
      singleInstance: false,
    );
    final staff = StaffRepository(db);
    final services = ServiceRepository(db);
    final sales = SaleRepository(db);
    final payments = PaymentRepository(db);
    final expenses = ExpenseRepository(db);

    final jun = await staff.create(name: 'Jun', type: StaffType.regular);
    final marlon = await staff.create(name: 'Marlon', type: StaffType.regular);
    final rico = await staff.create(name: 'Rico', type: StaffType.regular);
    final dodong = await staff.create(
      name: 'Dodong',
      type: StaffType.reliever,
      percentOverride: 50,
    );

    const menu = {
      'Haircut': 15000,
      'Haircut + Shave': 20000,
      'Shave': 8000,
      'Kids Cut': 12000,
      'Hair Color': 35000,
    };
    final serviceIds = <String, String>{};
    for (final entry in menu.entries) {
      serviceIds[entry.key] = await services.create(
        name: entry.key,
        price: entry.value,
      );
    }

    final now = DateTime.now();
    DateTime at(int daysAgo, int hour) =>
        DateTime(now.year, now.month, now.day - daysAgo, hour);

    Future<void> sell(
      String staffId,
      int percent,
      String service,
      DateTime when, {
      PaymentMethod method = PaymentMethod.cash,
    }) => sales.insert(
      Sale.record(
        id: newId(),
        now: when,
        staffId: staffId,
        staffPercent: percent,
        serviceId: serviceIds[service],
        serviceName: service,
        price: menu[service]!,
        paymentMethod: method,
      ),
    );

    // Today.
    for (var i = 0; i < 6; i++) {
      await sell(jun, 60, 'Haircut', at(0, 9));
    }
    for (final s in ['Haircut', 'Haircut + Shave', 'Haircut', 'Kids Cut']) {
      await sell(marlon, 60, s, at(0, 10));
    }
    for (final s in ['Haircut', 'Shave', 'Hair Color']) {
      await sell(rico, 60, s, at(0, 11), method: PaymentMethod.gcash);
    }
    await sell(dodong, 50, 'Haircut', at(0, 12));
    await sell(dodong, 50, 'Haircut', at(0, 13));

    // Earlier, so Marlon has a history and a balance.
    for (var i = 0; i < 5; i++) {
      await sell(marlon, 60, 'Haircut', at(1, 10));
      await sell(marlon, 60, 'Haircut + Shave', at(2, 10));
      await sell(marlon, 60, 'Haircut', at(8, 10));
    }
    await payments.insert(
      StaffPayment.record(
        id: newId(),
        now: at(1, 18),
        staffId: marlon,
        type: PaymentType.payout,
        amount: 50000,
        paymentMethod: PaymentMethod.cash,
      ),
    );
    await payments.insert(
      StaffPayment.record(
        id: newId(),
        now: at(2, 15),
        staffId: marlon,
        type: PaymentType.advance,
        amount: 30000,
        paymentMethod: PaymentMethod.cash,
        note: 'For fare',
      ),
    );

    await expenses.insert(
      Expense.record(
        id: newId(),
        now: at(0, 9),
        category: 'Supplies',
        amount: 25000,
        paymentMethod: PaymentMethod.cash,
        note: 'Blades and supplies',
      ),
    );
    await expenses.insert(
      Expense.record(
        id: newId(),
        now: at(1, 9),
        category: 'Electricity',
        amount: 120000,
        paymentMethod: PaymentMethod.gcash,
      ),
    );
    await expenses.insert(
      Expense.record(
        id: newId(),
        now: at(8, 9),
        category: 'Rent',
        amount: 750000,
        paymentMethod: PaymentMethod.cash,
      ),
    );

    return DemoShop._(db, marlon);
  }

  Future<void> close() => db.close();
}
