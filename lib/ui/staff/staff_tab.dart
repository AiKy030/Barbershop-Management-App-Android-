import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/money.dart';
import '../../domain/report.dart';
import '../settings/settings_sheets.dart';
import '../state/ledger.dart';
import '../state/shop_config.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../widgets/basics.dart';
import '../widgets/cards.dart';
import '../widgets/sheet.dart';
import 'staff_sheets.dart';

/// Staff tab: the list, or one staff member's page.
class StaffTab extends StatelessWidget {
  const StaffTab({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<ShellNav>();
    final staff = context.watch<ShopConfig>().staff;
    final selected = staff.where((s) => s.id == nav.staffDetailId).firstOrNull;
    return selected == null
        ? const StaffListView()
        : StaffDetailView(staff: selected);
  }
}

Color _balanceColor(AppColors colors, int balance) => balance > 0
    ? colors.moneyPositive
    : (balance < 0 ? colors.moneyNegative : colors.textSecondary);

String _typeLabel(StaffType type) =>
    type == StaffType.regular ? S.regular : S.reliever;

/// Total owed and every staff member with his balance.
/// Figma: 3:211 (light), 6:1599 (dark).
class StaffListView extends StatelessWidget {
  const StaffListView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final config = context.watch<ShopConfig>();
    final ledger = context.watch<Ledger>();
    final label = config.settings.staffLabel;
    final defaultPercent = config.settings.defaultStaffPercent;

    final active = config.staff.where((s) => s.active).toList();
    // Someone who left can still be owed money, or still owe the shop.
    final inactive = config.staff
        .where((s) => !s.active && ledger.balanceOf(s.id) != 0)
        .toList();
    final balances = [
      ...active,
      ...inactive,
    ].map((s) => ledger.balanceOf(s.id)).toList();

    Widget row(Staff s, bool isLast) {
      final balance = ledger.balanceOf(s.id);
      return AppRow(
        avatarInitial: s.name.characters.first.toUpperCase(),
        title: s.name,
        subtitle: S.typeAndPercent(
          _typeLabel(s.type),
          s.effectivePercent(defaultPercent),
        ),
        value: formatPesos(balance),
        valueColor: _balanceColor(colors, balance),
        isLast: isLast,
        onTap: () => context.read<ShellNav>().openStaff(s.id),
      );
    }

    List<Widget> rows(List<Staff> list) => [
      for (var i = 0; i < list.length; i++) row(list[i], i == list.length - 1),
    ];

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                ScreenHeader(title: S.staffPlural(label)),
                const SizedBox(height: 16),
                TutorialAnchor(
                  id: 'owedTile',
                  child: HeroCard(
                    label: S.totalOwedTo(label),
                    amount: formatPesos(ledger.owedToStaff),
                    subline: S.balanceSummary(
                      balances.where((b) => b > 0).length,
                      balances.where((b) => b < 0).length,
                      label,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (active.isEmpty)
                  EmptyCard(message: S.noStaff(label))
                else
                  Section(label: S.active, children: rows(active)),
                if (inactive.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Section(label: S.inactive, children: rows(inactive)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SecondaryButton(
              label: S.addStaff(label),
              onTap: () =>
                  showAppSheet<void>(context, (_) => const StaffSheet()),
            ),
          ),
        ],
      ),
    );
  }
}

/// One staff member: balance, Pay Out and Cash Advance, this week's entries.
/// Figma: 3:307 (light), 6:1695 (dark).
class StaffDetailView extends StatelessWidget {
  const StaffDetailView({super.key, required this.staff});

  final Staff staff;

  void _openSheet(BuildContext context, Widget sheet) {
    showAppSheet<void>(context, (_) => sheet);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final config = context.watch<ShopConfig>();
    final ledger = context.watch<Ledger>();
    final label = config.settings.staffLabel;
    final balance = ledger.balanceOf(staff.id);
    final terms = S
        .typeAndPercent(
          _typeLabel(staff.type),
          staff.effectivePercent(config.settings.defaultStaffPercent),
        )
        .replaceAll(' · ', ' ');
    final owes = balance > 0
        ? S.shopOwes(staff.name)
        : (balance < 0 ? S.owesShop(staff.name) : S.nothingOwed);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          NavBar(
            title: staff.name,
            leading: S.staffPlural(label),
            showBackArrow: true,
            onLeading: () => context.read<ShellNav>().closeStaff(),
          ),
          const SizedBox(height: 8),
          HeroCard(
            label: S.balance,
            amount: formatPesos(balance),
            amountColor: balance == 0
                ? colors.textPrimary
                : _balanceColor(colors, balance),
            subline: '$owes  ·  $terms',
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: TutorialAnchor(
                id: 'payButtons',
                child: Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: S.payOut,
                        onTap: () =>
                            _openSheet(context, PayOutSheet(staff: staff)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SecondaryButton(
                        label: S.cashAdvance,
                        onTap: () =>
                            _openSheet(context, CashAdvanceSheet(staff: staff)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          LedgerQuery<StaffHistory>(
            queryKey: staff.id,
            load: (ledger) => ledger.historyFor(staff.id),
            builder: (context, history) {
              if (history == null) return const SizedBox();
              final entries = history.entries;
              final showCarry = history.carriedOver != 0;
              if (entries.isEmpty && !showCarry) {
                return const EmptyCard(message: S.noEntriesThisWeek);
              }
              return Section(
                label: S.thisWeek,
                children: [
                  for (var i = 0; i < entries.length; i++)
                    _entryRow(
                      context,
                      entries[i],
                      isLast: i == entries.length - 1 && !showCarry,
                    ),
                  if (showCarry)
                    AppRow(
                      title: S.carriedOver,
                      subtitle: S.fromLastWeek,
                      value: formatPesos(history.carriedOver),
                      valueColor: history.carriedOver < 0
                          ? colors.moneyNegative
                          : null,
                      showChevron: false,
                      isLast: true,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _entryRow(
    BuildContext context,
    HistoryEntry entry, {
    required bool isLast,
  }) {
    final colors = context.colors;
    final day = S.shortDay(parseBusinessDate(entry.businessDate));
    final payment = entry.payment;
    final method = switch (payment?.paymentMethod?.name) {
      'cash' => S.cash,
      'gcash' => S.gcash,
      _ => null,
    };
    final (title, detail) = switch (entry.kind) {
      HistoryKind.earnings => (S.earnings, S.clientCount(entry.clients)),
      HistoryKind.heldTips => (S.gcashTips, null),
      HistoryKind.payout => (S.payout, method),
      HistoryKind.advance => (S.cashAdvanceEntry, payment?.note),
      HistoryKind.adjustment => (S.adjustment, payment?.note),
    };
    final sign = entry.amount > 0 ? '+' : '';
    return AppRow(
      title: title,
      subtitle: detail == null ? day : '$day · $detail',
      value: '$sign${formatPesos(entry.amount)}',
      valueColor: entry.kind == HistoryKind.advance
          ? colors.moneyNegative
          : colors.textPrimary,
      showChevron: false,
      isLast: isLast,
      onTap: switch (entry.kind) {
        HistoryKind.earnings ||
        HistoryKind.heldTips => () => showAppSheet<void>(
          context,
          (_) => DaySalesSheet(staff: staff, businessDate: entry.businessDate),
        ),
        _ => () => showAppSheet<void>(
          context,
          (_) => PaymentDetailSheet(payment: payment!),
        ),
      },
    );
  }
}
