import 'dart:io';

import 'package:barbershop_app/data/app_database.dart';
import 'package:barbershop_app/data/backup.dart';
import 'package:barbershop_app/data/excel_export.dart';
import 'package:barbershop_app/data/ledger_repositories.dart';
import 'package:barbershop_app/data/repositories.dart';
import 'package:barbershop_app/data/sale_repository.dart';
import 'package:barbershop_app/domain/entries.dart';
import 'package:barbershop_app/domain/models.dart';
import 'package:barbershop_app/domain/report.dart';
import 'package:barbershop_app/domain/sale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late String jun;
  late String dodong;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    final staff = StaffRepository(db);
    jun = await staff.create(name: 'Jun', type: StaffType.regular);
    dodong = await staff.create(
      name: 'Dodong',
      type: StaffType.reliever,
      percentOverride: 50,
    );
  });

  tearDown(() => db.close());

  Sale sale(DateTime now, {String? staff, int percent = 60, int tip = 0}) =>
      Sale.record(
        id: newId(),
        now: now,
        staffId: staff ?? jun,
        staffPercent: percent,
        serviceId: null,
        serviceName: 'Haircut',
        price: 15000,
        tip: tip,
        tipHeld: tip > 0,
        paymentMethod: PaymentMethod.cash,
      );

  group('payments', () {
    test('save, read back and void', () async {
      final repo = PaymentRepository(db);
      final payout = StaffPayment.record(
        id: newId(),
        now: DateTime(2026, 11, 11, 18),
        staffId: jun,
        type: PaymentType.payout,
        amount: 50000,
        paymentMethod: PaymentMethod.gcash,
      );
      final advance = StaffPayment.record(
        id: newId(),
        now: DateTime(2026, 11, 12, 9),
        staffId: jun,
        type: PaymentType.advance,
        amount: 20000,
        paymentMethod: PaymentMethod.cash,
        note: 'For fare',
      );
      await repo.insert(payout);
      await repo.insert(advance);

      final all = await repo.forStaff(jun);
      expect(all.map((p) => p.type), [PaymentType.payout, PaymentType.advance]);
      expect(all.first.amount, 50000);
      expect(all.first.paymentMethod, PaymentMethod.gcash);
      expect(all.last.note, 'For fare');
      expect(await repo.forRange('2026-11-12', '2026-11-12'), hasLength(1));
      expect(await repo.forStaff(dodong), isEmpty);

      await repo.setVoided(payout.id, true);
      expect((await repo.forStaff(jun)).first.voided, isTrue);
      expect(await db.query('staff_payments'), hasLength(2));
    });

    test('balance up to a date ignores later rows', () async {
      final sales = SaleRepository(db);
      await sales.insert(sale(DateTime(2026, 11, 10, 10)));
      await sales.insert(sale(DateTime(2026, 11, 12, 10)));
      await PaymentRepository(db).insert(
        StaffPayment.record(
          id: newId(),
          now: DateTime(2026, 11, 12, 18),
          staffId: jun,
          type: PaymentType.payout,
          amount: 4000,
        ),
      );
      expect(
        (await sales.balanceParts(upTo: '2026-11-11'))[jun]!.balance,
        9000,
      );
      expect((await sales.balanceParts())[jun]!.balance, 14000);
      expect(await sales.forStaff(jun), hasLength(2));
      expect(await sales.forRange('2026-11-10', '2026-11-12'), hasLength(2));
    });
  });

  group('expenses', () {
    test('save, edit, void and list newest first', () async {
      final repo = ExpenseRepository(db);
      final rent = Expense.record(
        id: newId(),
        now: DateTime(2026, 11, 5, 9),
        category: 'Rent',
        amount: 750000,
        paymentMethod: PaymentMethod.cash,
      );
      final blades = Expense.record(
        id: newId(),
        now: DateTime(2026, 11, 11, 9),
        category: 'Supplies',
        amount: 25000,
        paymentMethod: PaymentMethod.cash,
        note: 'Blades',
      );
      await repo.insert(rent);
      await repo.insert(blades);

      var month = await repo.forRange('2026-11-01', '2026-11-30');
      expect(month.map((e) => e.title), ['Blades', 'Rent']);
      expect(month.last.amount, 750000);

      await repo.update(
        blades.id,
        category: 'Other',
        amount: 30000,
        paymentMethod: PaymentMethod.gcash,
        note: null,
      );
      await repo.setVoided(rent.id, true);
      month = await repo.forRange('2026-11-01', '2026-11-30');
      expect(month.first.title, 'Other');
      expect(month.first.amount, 30000);
      expect(month.first.paymentMethod, PaymentMethod.gcash);
      expect(month.first.businessDate, '2026-11-11');
      expect(month.last.voided, isTrue);
      expect(await db.query('expenses'), hasLength(2));
    });
  });

  group('day closures', () {
    test('close, close again and reopen', () async {
      final repo = ClosureRepository(db);
      expect(await repo.all(), isEmpty);

      await repo.close('2026-11-11', cashCounted: 385000);
      expect((await repo.all())['2026-11-11']!.cashCounted, 385000);

      await repo.close('2026-11-11', cashCounted: null);
      final all = await repo.all();
      expect(all, hasLength(1));
      expect(all['2026-11-11']!.cashCounted, isNull);

      await repo.reopen('2026-11-11');
      expect(await repo.all(), isEmpty);
    });

    test('a manual reopen writes one log row', () async {
      final repo = ClosureRepository(db);
      await repo.close('2026-11-11', cashCounted: 1000);
      await repo.reopen('2026-11-11');
      final log = await repo.reopens('2026-11-11');
      expect(log.map((r) => r.reason), ['manual']);

      // Reopening a day that is not closed logs nothing.
      await repo.reopen('2026-11-11');
      await repo.reopen('2026-11-10');
      expect(await db.query('day_reopens'), hasLength(1));
    });

    test('a guarded change logs its reason and keeps the day locked', () async {
      final repo = ClosureRepository(db);
      await repo.close('2026-11-11', cashCounted: 1000);
      final closedAt = (await repo.all())['2026-11-11']!.closedAt;

      await repo.logReopen('2026-11-11', ReopenReason.addEntry);
      await repo.logReopen('2026-11-11', ReopenReason.editEntry);
      await repo.logReopen('2026-11-11', ReopenReason.voidEntry);
      await repo.logReopen('2026-11-11', ReopenReason.tally);

      expect((await repo.reopens('2026-11-11')).map((r) => r.reason), [
        'add_entry',
        'edit_entry',
        'void_entry',
        'tally',
      ]);
      final closure = (await repo.all())['2026-11-11']!;
      expect(closure.cashCounted, 1000);
      expect(closure.closedAt, closedAt);
      expect(await repo.reopens('2026-11-10'), isEmpty);

      final row = (await db.query('day_reopens')).first;
      expect(row['id'], isNotNull);
      expect(row['updated_at'], isNotNull);
    });
  });

  group('backdated entries', () {
    test('land on the chosen day and count in the balance', () async {
      final sales = SaleRepository(db);
      final payments = PaymentRepository(db);
      final expenses = ExpenseRepository(db);
      final now = DateTime(2026, 11, 12, 15);
      final past = DateTime(2026, 11, 3);

      await sales.insert(
        Sale.record(
          id: newId(),
          now: now,
          forDate: past,
          staffId: jun,
          staffPercent: 60,
          serviceId: null,
          serviceName: 'Haircut',
          price: 15000,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      await payments.insert(
        StaffPayment.record(
          id: newId(),
          now: now,
          forDate: past,
          staffId: jun,
          type: PaymentType.payout,
          amount: 5000,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      await expenses.insert(
        Expense.record(
          id: newId(),
          now: now,
          forDate: past,
          category: 'Supplies',
          amount: 2500,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      expect(await sales.forDate('2026-11-12'), isEmpty);
      expect((await sales.forDate('2026-11-03')).single.staffShare, 9000);
      expect(await payments.forRange('2026-11-12', '2026-11-12'), isEmpty);
      expect(
        (await payments.forRange('2026-11-03', '2026-11-03')).single.amount,
        5000,
      );
      expect(await expenses.forRange('2026-11-12', '2026-11-12'), isEmpty);
      expect(
        (await expenses.forRange('2026-11-03', '2026-11-03')).single.amount,
        2500,
      );

      // 9,000 earned minus the 5,000 payout, both on Nov 3.
      expect((await sales.balanceParts())[jun]!.balance, 4000);
      expect(
        (await sales.balanceParts(upTo: '2026-11-03'))[jun]!.balance,
        4000,
      );
      expect((await sales.balanceParts(upTo: '2026-11-02'))[jun], isNull);
    });
  });

  group('settings extras', () {
    test('backup date, tutorial seen and PIN hash', () async {
      final repo = SettingsRepository(db);
      await repo.setLastBackupAt(DateTime.utc(2026, 11, 11, 8));
      await repo.setTutorialSeen(true);
      await repo.setPinHash('salt:hash');
      var s = await repo.load();
      expect(s.lastBackupAt, DateTime.utc(2026, 11, 11, 8));
      expect(s.tutorialSeen, isTrue);
      expect(s.pinHash, 'salt:hash');

      await repo.setPinHash(null);
      s = await repo.load();
      expect(s.pinHash, isNull);
    });
  });

  group('Excel export', () {
    test('file names', () {
      expect(
        exportFileName(DateRange.day(DateTime(2026, 11, 11))),
        'Barbershop_2026-11-11.xlsx',
      );
      expect(
        exportFileName(DateRange.week(DateTime(2026, 11, 11))),
        'Barbershop_2026-11-09_to_2026-11-15.xlsx',
      );
    });

  });

  group('backup and restore', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('shop_backup_test');
    });

    tearDown(() => temp.delete(recursive: true));

    test('a backup restores every record onto a fresh database', () async {
      final factory = databaseFactoryFfiNoIsolate;
      final livePath = p.join(temp.path, 'live.db');
      var live = await AppDatabase.open(factory: factory, path: livePath);
      final staffId = await StaffRepository(live)
          .create(name: 'Marlon', type: StaffType.regular);
      await SettingsRepository(live).setShopName('Kanto Cuts');
      await SaleRepository(live)
          .insert(sale(DateTime(2026, 11, 11, 10), staff: staffId));
      await live.close();

      final backup = await writeBackup(
        databasePath: livePath,
        directory: temp.path,
        now: DateTime(2026, 11, 11),
      );
      expect(p.basename(backup.path), 'Barbershop_backup_2026-11-11.db');
      expect(await isValidBackup(backup.path, factory: factory), isTrue);

      // A "new phone": a fresh database, then restore over it.
      final newPath = p.join(temp.path, 'new.db');
      final fresh = await AppDatabase.open(factory: factory, path: newPath);
      expect((await SettingsRepository(fresh).load()).shopName, 'Barbershop');
      await fresh.close();

      final staged = await stageRestore(
        backupPath: backup.path,
        databasePath: newPath,
        factory: factory,
      );
      await commitRestore(stagedPath: staged!, databasePath: newPath);
      live =await AppDatabase.open(factory: factory, path: newPath);
      expect((await SettingsRepository(live).load()).shopName, 'Kanto Cuts');
      expect((await StaffRepository(live).all()).single.name, 'Marlon');
      expect(
        (await SaleRepository(live).balanceParts())[staffId]!.balance,
        9000,
      );
      await live.close();
    });

    test('files that are not a backup are rejected', () async {
      final factory = databaseFactoryFfiNoIsolate;
      final text = File(p.join(temp.path, 'notes.db'));
      await text.writeAsString('this is not a database');
      expect(await isValidBackup(text.path, factory: factory), isFalse);

      final otherPath = p.join(temp.path, 'other.db');
      final other = await factory.openDatabase(
        otherPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => db.execute('CREATE TABLE notes (id INTEGER)'),
        ),
      );
      await other.close();
      expect(await isValidBackup(otherPath, factory: factory), isFalse);
      expect(
        await isValidBackup(p.join(temp.path, 'missing.db'), factory: factory),
        isFalse,
      );
    });
  });
}
