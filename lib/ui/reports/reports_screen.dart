import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../domain/money.dart';
import '../../domain/report.dart';
import '../../domain/sale.dart';
import '../records/records_screen.dart';
import '../state/app_actions.dart';
import '../state/ledger.dart';
import '../state/shop_config.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/basics.dart';
import '../widgets/cards.dart';
import '../widgets/sheet.dart';

/// Reports tab: day, week or month totals, a sales bar chart, the per-staff
/// breakdown and Export to Excel. Figma: 3:519 (light), 6:1885 (dark).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Period _period = Period.week;
  late DateRange _range = DateRange.of(_period, DateTime.now());

  void _setPeriod(Period period) => setState(() {
    _period = period;
    // Keep looking at the same stretch of time when it is still current,
    // otherwise jump to today.
    final today = DateTime.now();
    final anchor = _range.containsKey(businessDateOf(today))
        ? today
        : _range.start;
    _range = DateRange.of(period, anchor);
  });

  void _shift(int step) =>
      setState(() => _range = _range.shifted(_period, step));

  String _rangeLabel() => switch (_period) {
    Period.day => S.shortDay(_range.start),
    Period.week => S.dayRange(_range.start, _range.end),
    Period.month => S.monthYear(_range.start),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final config = context.watch<ShopConfig>();
    final label = config.settings.staffLabel;
    final range = _range;
    // The Day view still shows the whole week's bars, with that day lit up.
    final chartRange = _period == Period.day
        ? DateRange.week(range.start)
        : range;
    final canGoForward = !range
        .shifted(_period, 1)
        .start
        .isAfter(DateTime.now());

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(child: ScreenHeader(title: S.reports)),
                    Pressable(
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(
                            CupertinoPageRoute<void>(
                              builder: (_) => const RecordsScreen(),
                            ),
                          ),
                      builder: (context, pressed) => Opacity(
                        opacity: pressed ? 0.5 : 1,
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            S.records,
                            style: AppText.headline.copyWith(
                              color: colors.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedControl<Period>(
                  options: const {
                    Period.day: S.day,
                    Period.week: S.week,
                    Period.month: S.month,
                  },
                  selected: _period,
                  onChanged: _setPeriod,
                ),
                const SizedBox(height: 16),
                LedgerQuery<(PeriodReport, PeriodReport)>(
                  queryKey: '${_period.name} ${range.startKey}',
                  load: (ledger) async {
                    final report = await ledger.report(range);
                    return (
                      report,
                      _period == Period.day
                          ? await ledger.report(chartRange)
                          : report,
                    );
                  },
                  builder: (context, data) {
                    if (data == null) return const SizedBox(height: 300);
                    final (report, chart) = data;
                    final totals = report.totals;
                    final staff =
                        config.staff
                            .where((s) => report.forStaff(s.id).clients > 0)
                            .toList()
                          ..sort(
                            (a, b) => report
                                .forStaff(b.id)
                                .earnings
                                .compareTo(report.forStaff(a.id).earnings),
                          );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HeroCard(
                          label: S.shopNetFor(_rangeLabel()),
                          amount: formatPesos(totals.shopNet),
                          amountColor: totals.shopNet < 0
                              ? colors.moneyNegative
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ArrowButton(
                                icon: LucideIcons.chevronLeft,
                                onTap: () => _shift(-1),
                              ),
                              _ArrowButton(
                                icon: LucideIcons.chevronRight,
                                onTap: canGoForward ? () => _shift(1) : null,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              _BarChart(
                                days: chartRange.days,
                                salesByDate: chart.salesByDate,
                                highlight: _period == Period.day
                                    ? range.startKey
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              Container(height: 1, color: colors.separator),
                              const SizedBox(height: 12),
                              StatRow(
                                stats: [
                                  (S.sales, formatPesos(totals.sales)),
                                  (S.shopShare, formatPesos(totals.shopShare)),
                                  (S.expenses, formatPesos(totals.expenses)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (staff.isEmpty)
                          const EmptyCard(message: S.noSales)
                        else
                          Section(
                            label: S.byStaff(label),
                            children: [
                              for (var i = 0; i < staff.length; i++)
                                AppRow(
                                  avatarInitial: staff[i].name.characters.first
                                      .toUpperCase(),
                                  title: staff[i].name,
                                  subtitle: S.clientCount(
                                    report.forStaff(staff[i].id).clients,
                                  ),
                                  value: formatPesos(
                                    report.forStaff(staff[i].id).earnings,
                                  ),
                                  valueColor: colors.textPrimary,
                                  showChevron: false,
                                  isLast: i == staff.length - 1,
                                ),
                            ],
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
            child: TutorialAnchor(
              id: 'export',
              child: PrimaryButton(
                label: S.exportToExcel,
                onTap: () => showAppSheet<void>(
                  context,
                  (_) => ExportSheet(initial: range),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

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
          width: 44,
          height: 32,
          child: Icon(icon, size: 22, color: colors.accent),
        ),
      ),
    );
  }
}

/// Daily sales bars. Days with no sales show a short gray stub.
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.days,
    required this.salesByDate,
    this.highlight,
  });

  final List<DateTime> days;
  final Map<String, int> salesByDate;

  /// Business date to draw in the accent color while the rest are muted.
  final String? highlight;

  static const double _maxBar = 84;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final values = [for (final d in days) salesByDate[businessDateOf(d)] ?? 0];
    final top = values.fold(0, (a, b) => a > b ? a : b);
    final many = days.length > 7;

    String label(DateTime d) {
      if (!many) return S.weekdayShort(d);
      // In a month, label the 1st, 8th, 15th, 22nd and 29th only.
      return (d.day - 1) % 7 == 0 ? '${d.day}' : '';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: _maxBar,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: many ? 0.6 : 0.52,
                      child: Container(
                        height: values[i] == 0
                            ? 6
                            : 10 + (_maxBar - 10) * values[i] / top,
                        decoration: BoxDecoration(
                          color: values[i] == 0
                              ? colors.bgFill
                              : (highlight == null ||
                                        highlight == businessDateOf(days[i])
                                    ? colors.accent
                                    : colors.accentSoft),
                          borderRadius: BorderRadius.circular(
                            values[i] == 0 ? 3 : (many ? 3 : 8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 18,
                  child: Text(
                    label(days[i]),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: AppText.footnote.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Choose the dates, then build the Excel file and open the share sheet.
class ExportSheet extends StatefulWidget {
  const ExportSheet({super.key, required this.initial});

  final DateRange initial;

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  late DateTime _from = widget.initial.start;
  late DateTime _to = _clampToToday(widget.initial.end);
  bool _busy = false;

  static DateTime _clampToToday(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return d.isAfter(today) ? today : d;
  }

  Future<void> _pick({required bool from}) async {
    final picked = await showAppSheet<DateTime>(
      context,
      (_) =>
          DateSheet(title: from ? S.from : S.to, initial: from ? _from : _to),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    final config = context.read<ShopConfig>();
    final ledger = context.read<Ledger>();
    final actions = context.read<AppActions>();
    try {
      final data = await ledger.exportData(
        DateRange(_from, _to),
        staffNames: {for (final s in config.staff) s.id: s.name},
        staffLabel: config.settings.staffLabel,
      );
      await actions.shareExport(data);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showToast(context, S.exportFailed, aboveTabBar: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: S.exportToExcel,
      children: [
        SheetValue(
          label: S.from,
          value: S.shortDay(_from),
          onTap: () => _pick(from: true),
        ),
        const SizedBox(height: 12),
        SheetValue(
          label: S.to,
          value: S.shortDay(_to),
          onTap: () => _pick(from: false),
        ),
        const SizedBox(height: 12),
        const SheetNote(S.exportNote),
        const SizedBox(height: 16),
        PrimaryButton(label: S.export, onTap: _busy ? null : _export),
      ],
    );
  }
}
