import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entries.dart';
import '../../domain/models.dart';
import '../../domain/money.dart';
import '../../domain/report.dart';
import '../../domain/sale.dart';
import '../state/app_actions.dart';
import '../state/ledger.dart';
import '../state/shop_config.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/basics.dart';
import '../widgets/cards.dart';
import '../widgets/day_guard.dart';
import '../widgets/sheet.dart';
import 'add_client_screen.dart';
import 'close_day_screen.dart';

/// Today tab. Figma: 3:2 (light), 6:1391 (dark), toast 6:508.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  Future<void> _addClient(BuildContext context) async {
    final config = context.read<ShopConfig>();
    final ledger = context.read<Ledger>();
    final sale = await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<Sale>(
        fullscreenDialog: true,
        builder: (_) => const AddClientScreen(),
      ),
    );
    if (sale == null || !context.mounted) return;
    final lasting = lastingContext(context);
    final staffName = config.staff.firstWhere((s) => s.id == sale.staffId).name;
    showToast(
      context,
      sale.businessDate == ledger.todayKey
          ? S.saved(staffName, sale.serviceName, formatPesos(sale.price))
          : S.savedFor(
              S.monthDay(parseBusinessDate(sale.businessDate)),
              staffName,
              formatPesos(sale.price),
            ),
      actionLabel: S.undo,
      onAction: () => guardedSave(
        lasting,
        days: [sale.businessDate],
        reason: ReopenReason.voidEntry,
        save: () => ledger.voidSale(sale.id),
      ),
      aboveFooterButton: true,
    );
  }

  Future<void> _closeDay(BuildContext context) async {
    final config = context.read<ShopConfig>();
    final actions = context.read<AppActions>();
    final closed = await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => const CloseDayScreen(),
      ),
    );
    if (closed != true || !context.mounted) return;
    showToast(context, S.dayClosedSaved, aboveFooterButton: true);

    // Remind about backups when the last one is more than 7 days old.
    final last = config.settings.lastBackupAt;
    final overdue = last == null || DateTime.now().difference(last).inDays > 7;
    if (!overdue) return;
    final backUp = await showAppSheet<bool>(
      context,
      (_) => const ConfirmSheet(
        title: S.backupReminderTitle,
        body: S.backupReminderBody,
        confirmLabel: S.backUpNow,
      ),
    );
    if (backUp == true && context.mounted) {
      await runBackup(context, actions, config);
    }
  }

  Future<void> _reopenDay(BuildContext context) async {
    final ledger = context.read<Ledger>();
    final reopen = await showAppSheet<bool>(
      context,
      (_) => const ConfirmSheet(
        title: S.reopenQuestion,
        body: S.reopenNote,
        confirmLabel: S.reopenDay,
      ),
    );
    if (reopen != true || !context.mounted) return;
    final unlocked = await unlockClosedDays(context, [
      ledger.todayKey,
    ], title: S.enterPinToReopenToday);
    if (!unlocked) return;
    await ledger.reopenToday();
    if (context.mounted) {
      showToast(context, S.dayReopened, aboveFooterButton: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final config = context.watch<ShopConfig>();
    final ledger = context.watch<Ledger>();
    final day = ledger.summary;
    final closed = ledger.todayClosed;
    final label = config.settings.staffLabel;
    final defaultPercent = config.settings.defaultStaffPercent;

    // Active staff, plus anyone inactive who still has sales today.
    final staff = config.staff
        .where((s) => s.active || day.forStaff(s.id).clients > 0)
        .toList();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.dayHeader(ledger.date).toUpperCase(),
                              style: AppText.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              S.today,
                              style: AppText.largeTitle.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TutorialAnchor(
                        id: 'closeDay',
                        child: Pressable(
                          onTap: () =>
                              closed ? _reopenDay(context) : _closeDay(context),
                          builder: (context, pressed) => Opacity(
                            opacity: pressed ? 0.5 : 1,
                            child: Container(
                              height: 48,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                closed ? S.reopenDay : S.closeDay,
                                style: AppText.headline.copyWith(
                                  color: colors.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                HeroCard(
                  label: S.shopNet,
                  amount: formatPesos(day.shopNet),
                  amountColor: day.shopNet < 0 ? colors.moneyNegative : null,
                  subline: S.cashAndGcash(
                    formatPesos(day.cashSales),
                    formatPesos(day.gcashSales),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      Container(height: 1, color: colors.separator),
                      const SizedBox(height: 12),
                      StatRow(
                        stats: [
                          (S.clients, '${day.clients}'),
                          (S.sales, formatPesos(day.sales)),
                          (S.expenses, formatPesos(day.expenses)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: S.shopShare,
                        value: formatPesos(day.shopShare),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        label: S.tipsToday,
                        value: formatPesos(day.tips),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (staff.isEmpty)
                  EmptyCard(message: S.noStaffToday(label))
                else
                  Section(
                    label: S.staffToday(label),
                    children: [
                      for (var i = 0; i < staff.length; i++)
                        _staffRow(
                          context,
                          staff[i],
                          defaultPercent,
                          day.forStaff(staff[i].id).clients,
                          day.forStaff(staff[i].id).earnings,
                          isLast: i == staff.length - 1,
                        ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (closed) ...[
                  Text(
                    S.todayClosedHint,
                    textAlign: TextAlign.center,
                    style: AppText.subhead.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TutorialAnchor(
                  id: 'addClient',
                  child: PrimaryButton(
                    label: S.addClient,
                    onTap: () => _addClient(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _staffRow(
    BuildContext context,
    Staff staff,
    int defaultPercent,
    int clients,
    int earnings, {
    required bool isLast,
  }) {
    final count = S.clientCount(clients);
    return AppRow(
      avatarInitial: staff.name.characters.first.toUpperCase(),
      title: staff.name,
      subtitle: staff.type == StaffType.reliever
          ? '$count · ${S.relieverPercent(staff.effectivePercent(defaultPercent))}'
          : count,
      value: formatPesos(earnings),
      valueColor: context.colors.textPrimary,
      isLast: isLast,
      onTap: () => context.read<ShellNav>().openStaff(staff.id),
    );
  }
}

/// Stat tile: label over value. Figma component 1:199.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.footnote.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.title.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}
