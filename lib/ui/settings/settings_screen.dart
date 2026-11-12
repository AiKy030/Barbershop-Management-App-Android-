import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart' show newId;
import '../../domain/models.dart';
import '../../domain/pin.dart';
import '../lock/pin_screen.dart';
import '../state/app_actions.dart';
import '../state/shop_config.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../tutorial/tutorial_screen.dart';
import '../widgets/basics.dart';
import '../widgets/cards.dart';
import '../widgets/sheet.dart';
import 'manage_screens.dart';
import 'settings_sheets.dart';

/// Settings tab. Figma: 3:655 (light), 6:2013 (dark).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _restore(BuildContext context) async {
    final actions = context.read<AppActions>();
    final String? path;
    try {
      path = await actions.pickBackupFile();
    } catch (_) {
      if (context.mounted) showToast(context, S.notABackup);
      return;
    }
    if (path == null || !context.mounted) return;
    if (!await actions.isBackupFile(path)) {
      if (context.mounted) showToast(context, S.notABackup);
      return;
    }
    if (!context.mounted) return;
    final confirmed = await showAppSheet<bool>(
      context,
      (_) => const ConfirmSheet(
        title: S.restoreTitle,
        body: S.restoreBody,
        confirmLabel: S.restore,
      ),
    );
    if (confirmed != true) return;
    final restored = await actions.restoreDatabase(path);
    if (!restored && context.mounted) showToast(context, S.notABackup);
  }

  Future<void> _pinLock(BuildContext context) async {
    final config = context.read<ShopConfig>();
    final navigator = Navigator.of(context, rootNavigator: true);
    final stored = config.settings.pinHash;
    if (stored == null) {
      final pin = await navigator.push(
        CupertinoPageRoute<String>(
          fullscreenDialog: true,
          builder: (_) => const PinSetupScreen(),
        ),
      );
      if (pin == null) return;
      await config.setPinHash(makePinHash(pin, newId()));
      if (context.mounted) showToast(context, S.pinTurnedOn);
    } else {
      final ok = await navigator.push(
        CupertinoPageRoute<bool>(
          fullscreenDialog: true,
          builder: (routeContext) => PinScreen(
            title: S.pinCurrent,
            onCancel: () => Navigator.of(routeContext).pop(),
            onEntered: (pin) {
              if (!verifyPin(pin, stored)) return S.wrongPin;
              Navigator.of(routeContext).pop(true);
              return null;
            },
          ),
        ),
      );
      if (ok != true) return;
      await config.setPinHash(null);
      if (context.mounted) showToast(context, S.pinTurnedOff);
    }
  }

  /// Turning the app lock off asks for the PIN. Turning it on does not.
  Future<void> _lockOnOpen(BuildContext context) async {
    final config = context.read<ShopConfig>();
    final stored = config.settings.pinHash;
    if (stored == null) return;
    if (!config.settings.lockOnOpen) {
      await config.setLockOnOpen(true);
      return;
    }
    final ok = await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<bool>(
        fullscreenDialog: true,
        builder: (routeContext) => PinScreen(
          title: S.pinToChangeLock,
          onCancel: () => Navigator.of(routeContext).pop(),
          onEntered: (pin) {
            if (!verifyPin(pin, stored)) return S.wrongPin;
            Navigator.of(routeContext).pop(true);
            return null;
          },
        ),
      ),
    );
    if (ok == true) await config.setLockOnOpen(false);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ShopConfig>();
    final settings = config.settings;
    final staffLabel = settings.staffLabel;
    final lastBackup = settings.lastBackupAt;

    void open(Widget screen) => Navigator.of(
      context,
      rootNavigator: true,
    ).push(CupertinoPageRoute<void>(builder: (_) => screen));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          const ScreenHeader(title: S.settings),
          const SizedBox(height: 16),
          Section(
            label: S.sectionShop,
            children: [
              AppRow(
                title: S.shopName,
                value: settings.shopName,
                onTap: () =>
                    showAppSheet<void>(context, (_) => const ShopNameSheet()),
              ),
              AppRow(
                title: S.defaultSplit,
                subtitle: S.splitSubtitle(staffLabel),
                value: S.splitValue(
                  settings.defaultStaffPercent,
                  settings.defaultShopPercent,
                ),
                isLast: true,
                onTap: () => showAppSheet<void>(
                  context,
                  (_) => const DefaultSplitSheet(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Section(
            label: S.sectionManage,
            children: [
              AppRow(
                title: S.servicesAndPrices,
                value: '${config.services.where((s) => s.active).length}',
                onTap: () => open(const ServicesScreen()),
              ),
              AppRow(
                title: S.staffPlural(staffLabel),
                value: '${config.staff.where((s) => s.active).length}',
                onTap: () => open(const StaffScreen()),
              ),
              AppRow(
                title: S.expenseCategories,
                value: '${config.categories.where((c) => c.active).length}',
                isLast: true,
                onTap: () => open(const CategoriesScreen()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Section(
            label: S.sectionBackup,
            children: [
              AppRow(
                title: S.backUpNow,
                subtitle: lastBackup == null
                    ? S.neverBackedUp
                    : S.lastBackup(
                        DateTime.now().difference(lastBackup).inDays,
                      ),
                onTap: () =>
                    runBackup(context, context.read<AppActions>(), config),
              ),
              AppRow(
                title: S.restoreFromFile,
                isLast: true,
                onTap: () => _restore(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Section(
            label: S.sectionApp,
            children: [
              AppRow(
                title: S.tutorial,
                value: S.start,
                valueColor: context.colors.accent,
                onTap: () => startTutorial(context),
              ),
              AppRow(
                title: S.appearance,
                value: switch (settings.appearance) {
                  AppearanceMode.system => S.appearanceSystem,
                  AppearanceMode.light => S.appearanceLight,
                  AppearanceMode.dark => S.appearanceDark,
                },
                onTap: () =>
                    showAppSheet<void>(context, (_) => const AppearanceSheet()),
              ),
              AppRow(
                title: S.language,
                value: S.english,
                onTap: () => showToast(context, S.englishOnly),
              ),
              AppRow(
                title: S.pinLock,
                subtitle: S.pinSubtitle,
                value: settings.pinHash == null ? S.off : S.on,
                isLast: settings.pinHash == null,
                onTap: () => _pinLock(context),
              ),
              if (settings.pinHash != null)
                AppRow(
                  title: S.askPinOnOpen,
                  value: settings.lockOnOpen ? S.on : S.off,
                  isLast: true,
                  onTap: () => _lockOnOpen(context),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
