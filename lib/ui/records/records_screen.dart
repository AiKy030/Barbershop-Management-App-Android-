import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show CupertinoPageRoute, CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/excel_export.dart';
import '../../data/records_repository.dart';
import '../../domain/entries.dart';
import '../../domain/money.dart';
import '../../domain/records.dart';
import '../../domain/report.dart';
import '../../domain/sale.dart';
import '../expenses/expenses_screen.dart';
import '../staff/staff_sheets.dart';
import '../state/app_actions.dart';
import '../state/ledger.dart';
import '../state/shop_config.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/basics.dart';
import '../widgets/day_guard.dart';
import '../widgets/sheet.dart';
import 'edit_entry_sheet.dart';
import 'pick_day_screen.dart';

/// Every entry in one table, like a simple spreadsheet. Opened from the
/// Records link on Reports. Figma: 21:3862.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key, this.day});

  /// When set, the table opens on this one day.
  final DateTime? day;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

/// One column of the part of the table that scrolls sideways.
class _Column {
  const _Column(this.label, this.width, {this.right = false});

  final String label;

  /// Null for the one column that takes the space left over.
  final double? width;
  final bool right;
}

/// One table row, ready to draw.
class _Line {
  const _Line({
    required this.businessDate,
    required this.addedLater,
    required this.voided,
    required this.cells,
  });

  final String businessDate;
  final bool addedLater;
  final bool voided;
  final List<String> cells;
}

class _RecordsScreenState extends State<RecordsScreen> {
  static const double _dateWidth = 72;
  static const double _headerHeight = 32;
  static const double _rowHeight = 48;

  late RecordsFilter _filter = widget.day == null
      ? RecordsFilter.lastSevenDays(RecordsTab.sales, DateTime.now())
      : RecordsFilter(
          tab: RecordsTab.sales,
          range: DateRange.day(widget.day!),
        );

  List<Object> _rows = const [];
  RecordsTotal _total = RecordsTotal.zero;
  bool _loaded = false;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _exporting = false;
  int _request = 0;
  int? _revision;
  String? _key;

  bool _searching = false;
  final _searchText = TextEditingController();
  Timer? _debounce;

  final _scroll = ScrollController();

  /// How far the table is scrolled sideways.
  final _sideways = ValueNotifier<double>(0);
  double _maxSideways = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchText.dispose();
    _scroll.dispose();
    _sideways.dispose();
    super.dispose();
  }

  Future<List<Object>> _page(
    RecordsRepository repo,
    RecordsFilter filter, {
    required int? limit,
    int offset = 0,
  }) => switch (filter.tab) {
    RecordsTab.sales => repo.sales(filter, limit: limit, offset: offset),
    RecordsTab.payouts => repo.payments(filter, limit: limit, offset: offset),
    RecordsTab.expenses => repo.expenses(filter, limit: limit, offset: offset),
  };

  /// Loads the first rows again when the filters or the records change.
  void _reloadIfNeeded(Ledger ledger) {
    final sameFilter = _key == _filter.key;
    if (_revision == ledger.revision && sameFilter) return;
    _revision = ledger.revision;
    _key = _filter.key;
    final request = ++_request;
    final filter = _filter;
    // After a change to the records, keep as many rows as were on screen.
    final limit = sameFilter
        ? math.max(RecordsRepository.pageSize, _rows.length)
        : RecordsRepository.pageSize;
    Future.wait([
      _page(ledger.records, filter, limit: limit),
      ledger.records.total(filter),
    ]).then((results) {
      if (!mounted || request != _request) return;
      final rows = results[0] as List<Object>;
      setState(() {
        _rows = rows;
        _total = results[1] as RecordsTotal;
        _hasMore = rows.length >= limit;
        _loadingMore = false;
        _loaded = true;
      });
      if (!sameFilter && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || !_loaded) return;
    _loadingMore = true;
    final request = _request;
    final ledger = context.read<Ledger>();
    final more = await _page(
      ledger.records,
      _filter,
      limit: RecordsRepository.pageSize,
      offset: _rows.length,
    );
    if (!mounted || request != _request) return;
    setState(() {
      _rows = [..._rows, ...more];
      _hasMore = more.length >= RecordsRepository.pageSize;
      _loadingMore = false;
    });
  }

  void _setFilter(RecordsFilter filter) => setState(() {
    if (filter.tab != _filter.tab) _sideways.value = 0;
    _filter = filter;
  });

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _setFilter(_filter.copyWith(search: text));
    });
  }

  void _closeSearch() {
    _debounce?.cancel();
    _searchText.clear();
    setState(() => _searching = false);
    _setFilter(_filter.copyWith(search: ''));
  }

  String _rangeLabel() => _filter.range.isSingleDay
      ? S.monthDay(_filter.range.start)
      : S.dayRange(_filter.range.start, _filter.range.end);

  Future<void> _pickRange() async {
    final range = await showAppSheet<DateRange>(
      context,
      (_) => _RangeSheet(initial: _filter.range),
    );
    if (range != null) _setFilter(_filter.copyWith(range: range));
  }

  Future<void> _pickStaff() async {
    final config = context.read<ShopConfig>();
    final label = config.settings.staffLabel;
    final picked = await showAppSheet<({String? value})>(
      context,
      (_) => OptionSheet(
        title: label,
        selected: _filter.staffId,
        options: [
          (null, S.allStaff(label)),
          for (final s in config.staff) (s.id, s.name),
        ],
      ),
    );
    if (picked != null) {
      _setFilter(_filter.copyWith(staffId: () => picked.value));
    }
  }

  Future<void> _pickCategory() async {
    final config = context.read<ShopConfig>();
    final used = await context.read<Ledger>().records.usedCategories();
    if (!mounted) return;
    final names = {
      for (final c in config.categories.where((c) => c.active)) c.name,
      ...used,
    };
    final picked = await showAppSheet<({String? value})>(
      context,
      (_) => OptionSheet(
        title: S.category,
        selected: _filter.category,
        options: [
          (null, S.allCategories),
          for (final name in names) (name, name),
        ],
      ),
    );
    if (picked != null) {
      _setFilter(_filter.copyWith(category: () => picked.value));
    }
  }

  Future<void> _export() async {
    if (_exporting) return;
    final config = context.read<ShopConfig>();
    final ledger = context.read<Ledger>();
    final actions = context.read<AppActions>();
    final filter = _filter;
    setState(() => _exporting = true);
    try {
      final rows = await _page(ledger.records, filter, limit: null);
      if (rows.isEmpty) {
        if (mounted) showToast(context, S.noRecords, aboveTabBar: false);
        return;
      }
      final bytes = buildRecordsWorkbook(
        tab: filter.tab,
        sales: rows.whereType<Sale>().toList(),
        payments: rows.whereType<StaffPayment>().toList(),
        expenses: rows.whereType<Expense>().toList(),
        staffNames: {for (final s in config.staff) s.id: s.name},
        staffLabel: config.settings.staffLabel,
        includeVoided: filter.showVoided,
      );
      await actions.shareXlsx(recordsFileName(filter), bytes);
    } catch (_) {
      if (mounted) showToast(context, S.exportFailed, aboveTabBar: false);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Opens the calendar. It comes back with a day when the owner asked to
  /// see that day's records.
  Future<void> _addPastEntry() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final day = await Navigator.of(context).push(
      CupertinoPageRoute<DateTime>(
        fullscreenDialog: true,
        builder: (_) => const PickDayScreen(),
      ),
    );
    if (day == null || !mounted) return;
    _debounce?.cancel();
    _searchText.clear();
    setState(() => _searching = false);
    _setFilter(
      RecordsFilter(tab: _filter.tab, range: DateRange.day(day)),
    );
  }

  /// Opens the sheet for one row: edit a sale or an expense, or look at a
  /// payout, advance or adjustment.
  void _open(Object entry) {
    const place = ToastPlace(aboveTabBar: false, aboveFooterButton: true);
    // Put the keyboard away, or it comes back when the sheet closes and
    // covers the Undo toast.
    FocusManager.instance.primaryFocus?.unfocus();
    showAppSheet<void>(
      context,
      (_) => switch (entry) {
        Sale s => EditEntrySheet(sale: s, place: place),
        StaffPayment p => PaymentDetailSheet(payment: p, place: place),
        Expense e => ExpenseSheet(expense: e, place: place),
        _ => const SizedBox.shrink(),
      },
    );
  }

  static String _method(PaymentMethod? method) => switch (method) {
    PaymentMethod.cash => S.cash,
    PaymentMethod.gcash => S.gcash,
    null => '',
  };

  /// The columns after Date. The first four fill the screen; the rest are
  /// reached by scrolling sideways.
  List<_Column> _columns(String staffLabel) => switch (_filter.tab) {
    RecordsTab.sales => [
      _Column(staffLabel, 70),
      const _Column(S.service, null),
      const _Column(S.price, 66, right: true),
      const _Column(S.paid, 58),
      const _Column(S.tip, 62, right: true),
      _Column(S.staffShareOf(staffLabel), 96, right: true),
      const _Column(S.shopShare, 90, right: true),
      const _Column(S.note, 160),
    ],
    RecordsTab.payouts => [
      _Column(staffLabel, 70),
      const _Column(S.type, null),
      const _Column(S.amount, 76, right: true),
      const _Column(S.paid, 58),
      const _Column(S.note, 180),
    ],
    RecordsTab.expenses => const [
      _Column(S.category, 92),
      _Column(S.note, null),
      _Column(S.amount, 76, right: true),
      _Column(S.paid, 58),
    ],
  };

  _Line _line(Object row, Map<String, String> staffNames) => switch (row) {
    Sale s => _Line(
      businessDate: s.businessDate,
      addedLater: isAddedLater(s.businessDate, s.createdAt),
      voided: s.voided,
      cells: [
        staffNames[s.staffId] ?? '',
        s.serviceName,
        formatPesos(s.price),
        _method(s.paymentMethod),
        s.tip == 0 ? '' : formatPesos(s.tip),
        formatPesos(s.staffShare),
        formatPesos(s.shopShare),
        s.note ?? '',
      ],
    ),
    StaffPayment p => _Line(
      businessDate: p.businessDate,
      addedLater: isAddedLater(p.businessDate, p.createdAt),
      voided: p.voided,
      cells: [
        staffNames[p.staffId] ?? '',
        switch (p.type) {
          PaymentType.payout => S.payout,
          PaymentType.advance => S.advance,
          PaymentType.adjustment => S.adjustment,
        },
        formatPesos(p.amount),
        _method(p.paymentMethod),
        p.note ?? '',
      ],
    ),
    Expense e => _Line(
      businessDate: e.businessDate,
      addedLater: isAddedLater(e.businessDate, e.createdAt),
      voided: e.voided,
      cells: [
        e.category,
        e.note ?? '',
        formatPesos(e.amount),
        _method(e.paymentMethod),
      ],
    ),
    _ => const _Line(
      businessDate: '',
      addedLater: false,
      voided: false,
      cells: [],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final config = context.watch<ShopConfig>();
    final ledger = context.watch<Ledger>();
    _reloadIfNeeded(ledger);
    final staffLabel = config.settings.staffLabel;
    final staffNames = {for (final s in config.staff) s.id: s.name};
    final columns = _columns(staffLabel);
    final scrollsSideways = columns.length > 4;

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _searching
                  ? _SearchBar(
                      controller: _searchText,
                      hint: S.searchHint(staffLabel),
                      onChanged: _onSearchChanged,
                      onCancel: _closeSearch,
                    )
                  : _NavBar(onSearch: () => setState(() => _searching = true)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: SegmentedControl<RecordsTab>(
                options: const {
                  RecordsTab.sales: S.sales,
                  RecordsTab.payouts: S.payouts,
                  RecordsTab.expenses: S.expenses,
                },
                selected: _filter.tab,
                onChanged: (tab) => _setFilter(_filter.copyWith(tab: tab)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ChipRow(
                  children: [
                    AppChip(
                      label: _rangeLabel(),
                      selected: true,
                      onTap: _pickRange,
                    ),
                    if (_filter.tab == RecordsTab.expenses)
                      AppChip(
                        label: _filter.category ?? S.allCategories,
                        selected: _filter.category != null,
                        onTap: _pickCategory,
                      )
                    else
                      AppChip(
                        label: _filter.staffId == null
                            ? S.allStaff(staffLabel)
                            : staffNames[_filter.staffId] ?? '',
                        selected: _filter.staffId != null,
                        onTap: _pickStaff,
                      ),
                    AppChip(
                      label: S.showVoided,
                      selected: _filter.showVoided,
                      onTap: () => _setFilter(
                        _filter.copyWith(showVoided: !_filter.showVoided),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TutorialAnchor(
                  id: 'recordsTable',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: colors.bgSurface,
                      child: LayoutBuilder(
                        builder: (context, box) =>
                            _table(context, box.maxWidth, columns, staffNames),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _Legend(showSwipeHint: scrollsSideways),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: S.addPastEntry,
                      onTap: _addPastEntry,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SecondaryButton(
                      label: S.export,
                      onTap: _exporting ? null : _export,
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

  Widget _table(
    BuildContext context,
    double width,
    List<_Column> columns,
    Map<String, String> staffNames,
  ) {
    final colors = context.colors;
    final viewport = width - _dateWidth;
    // The first four columns fill what is left after Date.
    final firstFixed = columns
        .take(4)
        .fold<double>(0, (sum, c) => sum + (c.width ?? 0));
    // Never so wide that the fourth column is pushed off the screen.
    final flexWidth = math.max(64.0, viewport - firstFixed);
    final widths = [for (final c in columns) c.width ?? flexWidth];
    final contentWidth = math.max(
      viewport,
      widths.fold<double>(0, (sum, w) => sum + w),
    );
    _maxSideways = math.max(0, contentWidth - viewport);
    if (_sideways.value > _maxSideways) _sideways.value = _maxSideways;

    Widget scrolling(List<Widget> cells) => ClipRect(
      child: ValueListenableBuilder<double>(
        valueListenable: _sideways,
        builder: (context, dx, child) =>
            Transform.translate(offset: Offset(-dx, 0), child: child),
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: contentWidth,
          maxWidth: contentWidth,
          child: Row(children: cells),
        ),
      ),
    );

    Widget cell(
      String text,
      double cellWidth,
      TextStyle style, {
      bool right = false,
    }) => Container(
      width: cellWidth,
      height: double.infinity,
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.separator)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );

    final headerStyle = AppText.caption.copyWith(color: colors.textSecondary);
    final header = Container(
      height: _headerHeight,
      color: colors.bgFill,
      child: Row(
        children: [
          Container(
            width: _dateWidth,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 10),
            child: Text(S.date.toUpperCase(), style: headerStyle),
          ),
          Expanded(
            child: scrolling([
              for (var i = 0; i < columns.length; i++)
                cell(
                  columns[i].label.toUpperCase(),
                  widths[i],
                  headerStyle,
                  right: columns[i].right,
                ),
            ]),
          ),
        ],
      ),
    );

    Widget rowBody(Object entry, bool pressed) {
      final line = _line(entry, staffNames);
      var style = AppText.footnote.copyWith(
        color: line.voided ? colors.textSecondary : colors.textPrimary,
      );
      if (line.voided) {
        style = style.copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: colors.textSecondary,
        );
      }
      return Container(
        height: _rowHeight,
        decoration: BoxDecoration(
          color: pressed ? colors.bgFill : null,
          border: Border(bottom: BorderSide(color: colors.separator)),
        ),
        child: Row(
          children: [
            Container(
              width: _dateWidth,
              padding: const EdgeInsets.only(left: 10),
              child: Row(
                children: [
                  if (line.addedLater) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      S.monthDay(parseBusinessDate(line.businessDate)),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: style,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: scrolling([
                for (var i = 0; i < columns.length; i++)
                  cell(
                    line.cells[i],
                    widths[i],
                    style,
                    right: columns[i].right,
                  ),
              ]),
            ),
          ],
        ),
      );
    }

    Widget row(Object entry) => Pressable(
      onTap: () => _open(entry),
      builder: (context, pressed) => rowBody(entry, pressed),
    );

    final totalStyle = AppText.footnote.copyWith(color: colors.textPrimary);
    final totalRow = Container(
      height: 44,
      color: colors.bgFill,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          SizedBox(
            width: _dateWidth - 10,
            child: Text(
              S.total,
              style: totalStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              S.rowCount(_total.count),
              style: totalStyle.copyWith(color: colors.textSecondary),
            ),
          ),
          Text(
            formatPesos(_total.sum),
            style: totalStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    final Widget body;
    if (!_loaded) {
      body = const SizedBox.expand();
    } else if (_rows.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            S.noRecords,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: colors.textSecondary),
          ),
        ),
      );
    } else {
      body = ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.zero,
        itemExtent: _rowHeight,
        itemCount: _rows.length,
        itemBuilder: (context, i) => row(_rows[i]),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _maxSideways == 0
          ? null
          : (details) => _sideways.value = (_sideways.value - details.delta.dx)
                .clamp(0.0, _maxSideways),
      child: Column(children: [header, Expanded(child: body), totalRow]),
    );
  }
}

/// Back link, title and Search link.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget link(Widget child, VoidCallback onTap) => Pressable(
      onTap: onTap,
      builder: (context, pressed) => Opacity(
        opacity: pressed ? 0.5 : 1,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(widthFactor: 1, child: child),
        ),
      ),
    );
    final linkStyle = AppText.body.copyWith(color: colors.accent);
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            S.records,
            style: AppText.headline.copyWith(color: colors.textPrimary),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: link(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.chevronLeft, size: 22, color: colors.accent),
                  const SizedBox(width: 2),
                  Text(S.reports, style: linkStyle),
                ],
              ),
              () => Navigator.of(context).maybePop(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: link(Text(S.search, style: linkStyle), onSearch),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onCancel,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colors.bgSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.search,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CupertinoTextField(
                      controller: controller,
                      autofocus: true,
                      decoration: null,
                      padding: EdgeInsets.zero,
                      maxLines: 1,
                      style: AppText.body.copyWith(color: colors.textPrimary),
                      cursorColor: colors.accent,
                      placeholder: hint,
                      placeholderStyle: AppText.body.copyWith(
                        color: colors.textSecondary,
                      ),
                      onChanged: onChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Pressable(
            onTap: onCancel,
            builder: (context, pressed) => Opacity(
              opacity: pressed ? 0.5 : 1,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    S.cancel,
                    style: AppText.body.copyWith(color: colors.accent),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the blue dot and the crossed-out rows mean.
class _Legend extends StatelessWidget {
  const _Legend({required this.showSwipeHint});

  final bool showSwipeHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = AppText.caption.copyWith(color: colors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '${S.legendAddedLater}    ${S.legendVoided}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ),
        if (showSwipeHint) ...[
          const SizedBox(height: 2),
          Text(S.swipeForMore, style: style),
        ],
      ],
    );
  }
}

/// From and To dates for the table.
class _RangeSheet extends StatefulWidget {
  const _RangeSheet({required this.initial});

  final DateRange initial;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  late DateTime _from = widget.initial.start;
  late DateTime _to = widget.initial.end;

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

  void _lastDays(int days) {
    final now = DateTime.now();
    Navigator.of(context).pop(
      DateRange(DateTime(now.year, now.month, now.day - (days - 1)), now),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: S.dates,
      children: [
        ChipRow(
          children: [
            AppChip(
              label: S.today,
              selected: false,
              onTap: () => _lastDays(1),
            ),
            AppChip(
              label: S.last7Days,
              selected: false,
              onTap: () => _lastDays(7),
            ),
            AppChip(
              label: S.last30Days,
              selected: false,
              onTap: () => _lastDays(30),
            ),
          ],
        ),
        const SizedBox(height: 6),
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
        const SizedBox(height: 16),
        PrimaryButton(
          label: S.done,
          onTap: () => Navigator.of(context).pop(DateRange(_from, _to)),
        ),
      ],
    );
  }
}
