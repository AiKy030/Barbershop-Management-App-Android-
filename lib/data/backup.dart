import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/sale.dart';
import 'app_database.dart';

/// `Barbershop_backup_YYYY-MM-DD.db`
String backupFileName(DateTime now) =>
    'Barbershop_backup_${businessDateOf(now)}.db';

/// Copies the whole database file into [directory] and returns the copy.
/// The database is one plain file, so the copy is the complete backup.
Future<File> writeBackup({
  required String databasePath,
  required String directory,
  required DateTime now,
}) => File(databasePath).copy(p.join(directory, backupFileName(now)));

const _requiredTables = [
  'settings',
  'staff',
  'services',
  'expense_categories',
  'sales',
  'staff_payments',
  'expenses',
  'day_closures',
];

/// True when [path] is a backup this version of the app can load: a SQLite
/// file with all of the app's tables, made by this schema version or older.
Future<bool> isValidBackup(String path, {DatabaseFactory? factory}) async {
  Database? db;
  try {
    db = await (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    final version = await db.getVersion();
    if (version < 1 || version > AppDatabase.schemaVersion) return false;
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = rows.map((r) => r['name']).toSet();
    if (!names.containsAll(_requiredTables)) return false;
    return (await db.query('settings')).length == 1;
  } catch (_) {
    return false;
  } finally {
    await db?.close();
  }
}

const _journalSuffixes = ['-journal', '-wal', '-shm'];

Future<void> _deleteWithJournals(String path) async {
  for (final suffix in ['', ..._journalSuffixes]) {
    final file = File('$path$suffix');
    if (await file.exists()) await file.delete();
  }
}

/// First half of a restore. Copies the backup beside the database, upgrades
/// the copy to this version of the app and checks it. Returns the path of
/// the ready copy, or null when the backup cannot be used.
///
/// The live database is not touched, so a bad backup loses nothing.
Future<String?> stageRestore({
  required String backupPath,
  required String databasePath,
  DatabaseFactory? factory,
}) async {
  final staged = '$databasePath.restore';
  try {
    await _deleteWithJournals(staged);
    await File(backupPath).copy(staged);
    final db = await AppDatabase.open(
      factory: factory,
      path: staged,
      singleInstance: false,
    );
    try {
      if ((await db.query('settings')).length != 1) {
        throw const FormatException('settings');
      }
    } finally {
      await db.close();
    }
    return staged;
  } catch (_) {
    try {
      await _deleteWithJournals(staged);
    } catch (_) {}
    return null;
  }
}

/// Second half of a restore: puts the copy from [stageRestore] in place of
/// the database. The database must be closed first. Leftover journal files
/// are removed.
Future<void> commitRestore({
  required String stagedPath,
  required String databasePath,
}) async {
  for (final suffix in _journalSuffixes) {
    final extra = File('$databasePath$suffix');
    if (await extra.exists()) await extra.delete();
    final stagedExtra = File('$stagedPath$suffix');
    if (await stagedExtra.exists()) await stagedExtra.delete();
  }
  // Same folder, so this is one rename and cannot leave half a file.
  await File(stagedPath).rename(databasePath);
}
