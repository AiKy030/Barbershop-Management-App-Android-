import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'data/app_database.dart';
import 'data/backup.dart';
import 'data/ledger_repositories.dart';
import 'data/records_repository.dart';
import 'data/repositories.dart';
import 'data/sale_repository.dart';
import 'domain/models.dart';
import 'domain/pin.dart';
import 'ui/home_shell.dart';
import 'ui/lock/pin_screen.dart';
import 'ui/state/app_actions.dart';
import 'ui/state/ledger.dart';
import 'ui/state/shop_config.dart';
import 'ui/strings.dart';
import 'ui/theme/app_colors.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppRoot());
}

/// Everything built on one open database.
class _Services {
  _Services(this.db, this.config, this.ledger, this.actions);

  final Database db;
  final ShopConfig config;
  final Ledger ledger;
  final AppActions actions;
}

/// Opens the database, provides the app state, and handles the two things
/// that sit above the screens: the PIN lock and restoring a backup.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  /// Leaving the app for longer than this locks it again (when a PIN is set).
  static const _lockAfter = Duration(seconds: 60);

  _Services? _services;
  int _generation = 0;
  bool _locked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open(lockIfPinSet: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null &&
          DateTime.now().difference(pausedAt) > _lockAfter &&
          (_services?.config.settings.locksApp ?? false)) {
        setState(() => _locked = true);
      }
    }
  }

  Future<void> _open({required bool lockIfPinSet}) async {
    final path = await AppDatabase.defaultPath();
    final db = await AppDatabase.open(path: path, keepCopyBeforeUpgrade: true);
    final config = ShopConfig(
      settingsRepo: SettingsRepository(db),
      staffRepo: StaffRepository(db),
      serviceRepo: ServiceRepository(db),
      categoryRepo: ExpenseCategoryRepository(db),
    );
    await config.load();
    final ledger = Ledger(
      sales: SaleRepository(db),
      payments: PaymentRepository(db),
      expenses: ExpenseRepository(db),
      closures: ClosureRepository(db),
      records: RecordsRepository(db),
    );
    await ledger.load();
    final actions = AppActions(
      databasePath: path,
      flushDatabase: () async {
        // Only matters when the phone keeps a write-ahead log; harmless
        // otherwise.
        try {
          await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
        } catch (_) {}
      },
      restoreDatabase: _restore,
    );
    if (!mounted) return;
    setState(() {
      _services = _Services(db, config, ledger, actions);
      _generation++;
      if (lockIfPinSet) _locked = config.settings.locksApp;
    });
  }

  /// False when the backup could not be used. The records on the phone are
  /// then left as they were.
  Future<bool> _restore(String backupPath) async {
    final current = _services;
    if (current == null) return false;
    final databasePath = current.actions.databasePath;
    // The backup is copied and upgraded first. Only a copy that opens
    // cleanly replaces the records on the phone.
    final staged = await stageRestore(
      backupPath: backupPath,
      databasePath: databasePath,
    );
    if (staged == null) return false;
    setState(() => _services = null);
    await current.db.close();
    await commitRestore(stagedPath: staged, databasePath: databasePath);
    await _open(lockIfPinSet: false);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    if (services == null) {
      return ColoredBox(color: AppColors.light.bgSurface);
    }
    return MultiProvider(
      key: ValueKey(_generation),
      providers: [
        ChangeNotifierProvider.value(value: services.config),
        ChangeNotifierProvider.value(value: services.ledger),
        ChangeNotifierProvider(create: (_) => ShellNav()),
        Provider.value(value: services.actions),
      ],
      child: ShopApp(
        locked: _locked,
        onUnlocked: () => setState(() => _locked = false),
      ),
    );
  }
}

class ShopApp extends StatelessWidget {
  const ShopApp({super.key, required this.locked, required this.onUnlocked});

  final bool locked;
  final VoidCallback onUnlocked;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ShopConfig>().settings;
    final pinHash = settings.pinHash;
    return MaterialApp(
      title: settings.shopName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: switch (settings.appearance) {
        AppearanceMode.system => ThemeMode.system,
        AppearanceMode.light => ThemeMode.light,
        AppearanceMode.dark => ThemeMode.dark,
      },
      builder: (context, child) => Stack(
        children: [
          ?child,
          if (locked && pinHash != null)
            Positioned.fill(
              child: PinScreen(
                title: S.enterPin,
                onEntered: (pin) {
                  if (!verifyPin(pin, pinHash)) return S.wrongPin;
                  onUnlocked();
                  return null;
                },
              ),
            ),
        ],
      ),
      home: const HomeShell(),
    );
  }
}
