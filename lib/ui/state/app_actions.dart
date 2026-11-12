import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup.dart';
import '../../data/excel_export.dart';
import '../strings.dart';
import '../widgets/sheet.dart';
import 'shop_config.dart';

/// Things that reach outside the app: the share sheet, the file picker, and
/// swapping the database file on restore.
class AppActions {
  AppActions({
    required this.databasePath,
    required this.flushDatabase,
    required this.restoreDatabase,
  });

  final String databasePath;

  /// Makes sure everything saved so far is in the main database file.
  final Future<void> Function() flushDatabase;

  /// Closes the database, replaces it with the file at the given path, and
  /// restarts the app's screens on the restored records. False when the
  /// file could not be used; nothing is changed then.
  final Future<bool> Function(String backupPath) restoreDatabase;

  /// Writes the whole database to one file and opens the share sheet.
  Future<void> backUpNow() async {
    await flushDatabase();
    final directory = await getTemporaryDirectory();
    final file = await writeBackup(
      databasePath: databasePath,
      directory: directory.path,
      now: DateTime.now(),
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/octet-stream')],
      ),
    );
  }

  /// Lets the owner pick a file. Returns its path, or null when cancelled.
  Future<String?> pickBackupFile() async {
    final files = await FilePicker.pickFiles();
    return files.isEmpty ? null : files.first.path;
  }

  Future<bool> isBackupFile(String path) => isValidBackup(path);

  /// Builds the Excel file and opens the share sheet.
  Future<void> shareExport(ExportData data) =>
      shareXlsx(exportFileName(data.range), buildWorkbook(data));

  /// Writes an Excel file and opens the share sheet.
  Future<void> shareXlsx(String fileName, List<int> bytes) async {
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
      ),
    );
  }
}

/// Back up now, record the date, and say so if it fails.
Future<void> runBackup(
  BuildContext context,
  AppActions actions,
  ShopConfig config,
) async {
  try {
    await actions.backUpNow();
    await config.markBackedUp();
  } catch (_) {
    if (context.mounted) showToast(context, S.backupFailed);
  }
}
