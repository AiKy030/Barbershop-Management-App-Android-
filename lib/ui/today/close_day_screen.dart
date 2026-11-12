import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/money.dart';
import '../state/ledger.dart';
import '../state/shop_config.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/basics.dart';
import '../widgets/cards.dart';
import '../widgets/sheet.dart';

/// Full-screen Close Day: summary, cash drawer check, then lock.
/// Figma: 6:859 (light), 6:2646 (dark). Pops with true when the day is closed.
class CloseDayScreen extends StatefulWidget {
  const CloseDayScreen({super.key});

  @override
  State<CloseDayScreen> createState() => _CloseDayScreenState();
}

class _CloseDayScreenState extends State<CloseDayScreen> {
  /// Centavos the owner counted, or null when not typed yet.
  int? _counted;
  bool _saving = false;

  Future<void> _typeCount() async {
    final counted = await showAppSheet<int>(
      context,
      (_) => _CountSheet(initial: _counted),
    );
    if (counted != null) setState(() => _counted = counted);
  }

  Future<void> _close() async {
    if (_saving) return;
    setState(() => _saving = true);
    await context.read<Ledger>().closeToday(cashCounted: _counted);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ledger = context.watch<Ledger>();
    final label = context.watch<ShopConfig>().settings.staffLabel;
    final day = ledger.summary;
    final drawer = ledger.drawer;
    final counted = _counted;
    final difference = counted == null ? null : drawer.difference(counted);

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  NavBar(
                    title: S.closeDay,
                    leading: S.cancel,
                    onLeading: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 8),
                  Section(
                    label: S.dayHeader(ledger.date),
                    children: [
                      AppRow(
                        title: S.sales,
                        subtitle: S.clientCount(day.clients),
                        value: formatPesos(day.sales),
                        valueColor: colors.textPrimary,
                        showChevron: false,
                      ),
                      AppRow(
                        title: S.staffShare(label),
                        value: formatPesos(-day.staffShare),
                        showChevron: false,
                      ),
                      AppRow(
                        title: S.expenses,
                        value: formatPesos(-day.expenses),
                        showChevron: false,
                      ),
                      AppRow(
                        title: S.shopNet,
                        value: formatPesos(day.shopNet),
                        valueColor: colors.textPrimary,
                        showChevron: false,
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Section(
                    label: S.cashDrawer,
                    children: [
                      AppRow(
                        title: S.cashSales,
                        value: formatPesos(drawer.cashSales),
                        valueColor: colors.textPrimary,
                        showChevron: false,
                      ),
                      AppRow(
                        title: S.paidOutInCash,
                        subtitle: S.paidOutDetail,
                        value: formatPesos(-drawer.paidOut),
                        showChevron: false,
                      ),
                      AppRow(
                        title: S.shouldBeInDrawer,
                        value: formatPesos(drawer.expected),
                        valueColor: colors.textPrimary,
                        showChevron: false,
                      ),
                      AppRow(
                        title: S.cashCounted,
                        subtitle: switch (difference) {
                          null => S.tapToCount,
                          0 => S.matches,
                          < 0 => S.shortBy(formatPesos(-difference)),
                          _ => S.overBy(formatPesos(difference)),
                        },
                        value: counted == null ? null : formatPesos(counted),
                        valueColor: switch (difference) {
                          null => null,
                          0 => colors.moneyPositive,
                          < 0 => colors.moneyNegative,
                          _ => colors.textPrimary,
                        },
                        isLast: true,
                        onTap: _typeCount,
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
                  Text(
                    S.closeNote,
                    textAlign: TextAlign.center,
                    style: AppText.subhead.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TutorialAnchor(
                    id: 'closeLock',
                    child: PrimaryButton(
                      label: S.closeDayAndLock,
                      onTap: _saving ? null : _close,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Type the cash counted. Zero is allowed. Pops with centavos.
class _CountSheet extends StatefulWidget {
  const _CountSheet({this.initial});

  final int? initial;

  @override
  State<_CountSheet> createState() => _CountSheetState();
}

class _CountSheetState extends State<_CountSheet> {
  late final _amount = TextEditingController(
    text: widget.initial == null ? '' : pesosInputText(widget.initial!),
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = parsePesos(_amount.text);
    return AppSheet(
      title: S.cashCounted,
      children: [
        BigAmountField(
          controller: _amount,
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: S.done,
          onTap: amount == null
              ? null
              : () => Navigator.of(context).pop(amount),
        ),
      ],
    );
  }
}
