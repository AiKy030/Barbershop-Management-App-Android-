import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../domain/money.dart';
import '../../domain/records.dart';
import '../../domain/sale.dart';
import '../../domain/tally.dart';
import '../state/ledger.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/basics.dart';
import '../widgets/cards.dart';
import '../widgets/sheet.dart';
import 'add_entries_screen.dart';

/// First step of adding to a past day: choose the day on a month calendar.
/// Pops with a day when the owner taps "View Records for" that day.
/// Figma: 21:4329.
class PickDayScreen extends StatefulWidget {
  const PickDayScreen({super.key});

  @override
  State<PickDayScreen> createState() => _PickDayScreenState();
}

class _PickDayScreenState extends State<PickDayScreen> {
  late final DateTime _today = _dateOnly(DateTime.now());

  /// Yesterday is the day most often forgotten.
  late DateTime _picked = () {
    final yesterday = DateTime(_today.year, _today.month, _today.day - 1);
    return isPickableDay(yesterday, _today) ? yesterday : _today;
  }();
  late DateTime _month = DateTime(_picked.year, _picked.month);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _canGoBack =>
      _month.year > firstEntryYear || _month.month > DateTime.january;
  bool get _canGoForward =>
      _month.isBefore(DateTime(_today.year, _today.month));

  void _shift(int step) => setState(() {
    _month = DateTime(_month.year, _month.month + step);
  });

  void _addEntries() => Navigator.of(context).push(
    CupertinoPageRoute<void>(builder: (_) => AddEntriesScreen(day: _picked)),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ledger = context.watch<Ledger>();
    final key = businessDateOf(_picked);
    final closed = ledger.isClosed(key);
    final dayLabel = S.monthDay(_picked);
    final monthStart = businessDateOf(_month);
    final monthEnd = businessDateOf(DateTime(_month.year, _month.month + 1, 0));

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  NavBar(
                    title: S.addPastEntry,
                    leading: S.cancel,
                    onLeading: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 8),
                  TutorialAnchor(
                    id: 'calendar',
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
                      decoration: BoxDecoration(
                        color: colors.bgSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _Arrow(
                                icon: LucideIcons.chevronLeft,
                                onTap: _canGoBack ? () => _shift(-1) : null,
                              ),
                              Expanded(
                                child: Text(
                                  S.monthYear(_month),
                                  textAlign: TextAlign.center,
                                  style: AppText.headline.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              _Arrow(
                                icon: LucideIcons.chevronRight,
                                onTap: _canGoForward ? () => _shift(1) : null,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              for (final letter in S.weekdayLetters)
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      letter,
                                      style: AppText.caption.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LedgerQuery<Set<String>>(
                            queryKey: monthStart,
                            load: (ledger) => ledger.records.daysWithEntries(
                              monthStart,
                              monthEnd,
                            ),
                            builder: (context, withEntries) => _MonthGrid(
                              month: _month,
                              today: _today,
                              picked: _picked,
                              withEntries: withEntries ?? const {},
                              onPick: (day) => setState(() => _picked = day),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const _CalendarLegend(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LedgerQuery<DayEntries>(
                    queryKey: key,
                    load: (ledger) => ledger.records.entriesOn(key),
                    builder: (context, entries) {
                      final (title, subtitle) = switch (entries) {
                        null => ('', ''),
                        DayEntries(isEmpty: true) => (
                          S.noEntriesYet,
                          S.nothingRecorded,
                        ),
                        DayEntries(clients: 0) => (
                          S.noClientsRecorded,
                          S.otherEntries(entries.others),
                        ),
                        _ => (
                          S.clientsRecorded(entries.clients),
                          S.salesSoFar(formatPesos(entries.sales)),
                        ),
                      };
                      return Section(
                        label: S.dayHeader(_picked),
                        children: [
                          AppRow(
                            title: title,
                            subtitle: subtitle,
                            showChevron: false,
                          ),
                          AppRow(
                            title: S.dayStatus,
                            subtitle: closed
                                ? S.statusClosedNote
                                : S.statusOpenNote,
                            value: closed ? S.statusClosed : S.statusOpen,
                            valueColor: closed
                                ? colors.textSecondary
                                : colors.moneyPositive,
                            showChevron: false,
                            isLast: true,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryButton(
                    label: S.addEntriesTo(dayLabel),
                    onTap: _addEntries,
                  ),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: S.viewRecordsFor(dayLabel),
                    onTap: () => Navigator.of(context).pop(_picked),
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

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      builder: (context, pressed) => Opacity(
        opacity: onTap == null ? 0.3 : (pressed ? 0.5 : 1),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 22, color: colors.accent),
        ),
      ),
    );
  }
}

/// The days of one month, a week per row, Sunday first.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.picked,
    required this.withEntries,
    required this.onPick,
  });

  final DateTime month;
  final DateTime today;
  final DateTime picked;

  /// Business dates in this month that have entries.
  final Set<String> withEntries;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final cells = monthCells(month);
    return Column(
      children: [
        for (var i = 0; i < cells.length; i += 7)
          Row(
            children: [
              for (var j = i; j < i + 7; j++)
                Expanded(
                  child: j < cells.length && cells[j] != null
                      ? _DayCell(
                          day: cells[j]!,
                          isToday: cells[j] == today,
                          isPicked: cells[j] == picked,
                          canPick: isPickableDay(cells[j]!, today),
                          hasEntries: withEntries.contains(
                            businessDateOf(cells[j]!),
                          ),
                          onTap: () => onPick(cells[j]!),
                        )
                      : const SizedBox(height: 50),
                ),
            ],
          ),
      ],
    );
  }
}

/// One day: a 36 px circle with the day number and a dot under it when the
/// day has entries. The whole cell is the tap target.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isPicked,
    required this.canPick,
    required this.hasEntries,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isPicked;
  final bool canPick;
  final bool hasEntries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: canPick ? onTap : null,
      builder: (context, pressed) => Opacity(
        opacity: canPick ? (pressed ? 0.6 : 1) : 0.45,
        child: SizedBox(
          height: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPicked ? colors.accent : null,
                  border: isToday && !isPicked
                      ? Border.all(width: 1.5, color: colors.accent)
                      : null,
                ),
                child: Text(
                  '${day.day}',
                  style: (isPicked ? AppText.headline : AppText.body).copyWith(
                    color: isPicked ? colors.textOnAccent : colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasEntries ? colors.accent : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = AppText.caption.copyWith(color: colors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '${S.legendHasEntries}     ${S.legendToday}     '
              '${S.legendFuture}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
