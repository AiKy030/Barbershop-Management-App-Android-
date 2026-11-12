import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart' show newId;
import '../../domain/entries.dart';
import '../../domain/models.dart';
import '../../domain/money.dart';
import '../../domain/sale.dart';
import '../../domain/tally.dart';
import '../state/ledger.dart';
import '../state/shop_config.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/basics.dart';
import '../widgets/cards.dart';
import '../widgets/day_guard.dart';
import '../widgets/sheet.dart';

enum _Tab { clients, expense, payout, advance }

/// Saves one thing for the picked day. True when it was saved.
typedef _Save =
    Future<bool> Function({
      required ReopenReason reason,
      required String message,
      required Future<void> Function() change,
      required Future<void> Function() undo,
    });

/// Second step of adding to a past day: a tally of clients, or one
/// expense, payout or advance, all saved to [day]. Figma: 21:4564.
class AddEntriesScreen extends StatefulWidget {
  const AddEntriesScreen({super.key, required this.day, this.demo = false});

  final DateTime day;

  /// The tutorial shows the grid already filled in with sample counts.
  final bool demo;

  @override
  State<AddEntriesScreen> createState() => _AddEntriesScreenState();
}

class _AddEntriesScreenState extends State<AddEntriesScreen> {
  _Tab _tab = _Tab.clients;

  /// Goes up after each save, which gives the tab a fresh, empty form.
  int _formNumber = 0;

  Future<bool> _save({
    required ReopenReason reason,
    required String message,
    required Future<void> Function() change,
    required Future<void> Function() undo,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final saved = await changeEntry(
      context,
      days: [businessDateOf(widget.day)],
      reason: reason,
      message: message,
      change: change,
      undo: undo,
      place: const ToastPlace(aboveTabBar: false, aboveFooterButton: true),
    );
    if (saved && mounted) setState(() => _formNumber++);
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final day = widget.day;
    final isToday = businessDateOf(day) == businessDateOf(DateTime.now());

    final header = <Widget>[
      NavBar(
        title: S.shortDay(day),
        leading: S.back,
        showBackArrow: true,
        onLeading: () => Navigator.of(context).pop(),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.accentSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isToday ? S.todayNoticeTitle : S.pastDayTitle,
              style: AppText.headline.copyWith(color: colors.accent),
            ),
            const SizedBox(height: 2),
            Text(
              isToday ? S.todayNoticeBody : S.pastDayBody(S.dayHeader(day)),
              style: AppText.subhead.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SegmentedControl<_Tab>(
        options: const {
          _Tab.clients: S.tabClients,
          _Tab.expense: S.tabExpense,
          _Tab.payout: S.tabPayout,
          _Tab.advance: S.tabAdvance,
        },
        selected: _tab,
        onChanged: (tab) {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => _tab = tab);
        },
      ),
      const SizedBox(height: 16),
    ];

    final key = ValueKey('${_tab.name} $_formNumber');
    return AppScaffold(
      body: SafeArea(
        child: switch (_tab) {
          _Tab.clients => _ClientsTab(
            key: key,
            day: day,
            header: header,
            save: _save,
            demo: widget.demo,
          ),
          _Tab.expense => _ExpenseTab(
            key: key,
            day: day,
            header: header,
            save: _save,
          ),
          _Tab.payout => _PaymentTab(
            key: key,
            day: day,
            header: header,
            save: _save,
            type: PaymentType.payout,
          ),
          _Tab.advance => _PaymentTab(
            key: key,
            day: day,
            header: header,
            save: _save,
            type: PaymentType.advance,
          ),
        },
      ),
    );
  }
}

/// The scrolling part with a footer under it.
class _TabFrame extends StatelessWidget {
  const _TabFrame({
    required this.children,
    required this.button,
    this.note,
  });

  final List<Widget> children;
  final String? note;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: children,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (note != null) ...[
                Text(
                  note!,
                  textAlign: TextAlign.center,
                  style: AppText.subhead.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              button,
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: AppText.caption.copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}

/// A white card for form fields that were made for bottom sheets.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// ---------------------------------------------------------------- clients

class _ClientsTab extends StatefulWidget {
  const _ClientsTab({
    super.key,
    required this.day,
    required this.header,
    required this.save,
    this.demo = false,
  });

  final DateTime day;
  final List<Widget> header;
  final _Save save;
  final bool demo;

  @override
  State<_ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<_ClientsTab> {
  /// Count per box, keyed by staff id then service id.
  final Map<(String, String), int> _counts = {};
  bool _saving = false;

  /// Sample counts for the tutorial, one row per staff member.
  static const _demoCounts = [
    [8, 2, 1, 1],
    [7, 3, 0, 1],
    [6, 1, 2, 0],
  ];

  @override
  void initState() {
    super.initState();
    if (!widget.demo) return;
    final config = context.read<ShopConfig>();
    final staff = config.staff.where((s) => s.active).toList();
    final services = config.services.where((s) => s.active).toList();
    for (var i = 0; i < _demoCounts.length && i < staff.length; i++) {
      for (var j = 0; j < _demoCounts[i].length && j < services.length; j++) {
        _counts[(staff[i].id, services[j].id)] = _demoCounts[i][j];
      }
    }
  }

  List<TallyLine> _lines(List<Staff> staff, List<Service> services, int def) => [
    for (final person in staff)
      for (final service in services)
        if ((_counts[(person.id, service.id)] ?? 0) > 0)
          TallyLine(
            staffId: person.id,
            staffPercent: person.effectivePercent(def),
            serviceId: service.id,
            serviceName: service.name,
            price: service.price,
            count: _counts[(person.id, service.id)]!,
          ),
  ];

  Future<void> _saveTally(List<TallyLine> lines, int clients) async {
    if (_saving) return;
    setState(() => _saving = true);
    final ledger = context.read<Ledger>();
    final batchId = newId();
    final sales = tallySales(
      lines: lines,
      now: DateTime.now(),
      forDate: widget.day,
      batchId: batchId,
      newId: newId,
    );
    // The whole tally is one save and one Undo.
    final saved = await widget.save(
      reason: ReopenReason.tally,
      message: S.savedClientsFor(clients, S.monthDay(widget.day)),
      change: () => ledger.addSales(sales),
      undo: () => ledger.voidBatch(batchId),
    );
    if (!saved && mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final config = context.watch<ShopConfig>();
    final label = config.settings.staffLabel;
    final staff = config.staff.where((s) => s.active).toList();
    final services = config.services.where((s) => s.active).toList();
    final lines = _lines(staff, services, config.settings.defaultStaffPercent);
    final summary = TallySummary.of(lines);

    Widget row(String title, String value, {String? subtitle, bool last = false}) =>
        AppRow(
          title: title,
          subtitle: subtitle,
          value: value,
          valueColor: colors.textPrimary,
          showChevron: false,
          isLast: last,
        );

    return _TabFrame(
      note: S.savedAsCash,
      button: PrimaryButton(
        label: S.saveClientsTo(summary.clients, S.monthDay(widget.day)),
        onTap: summary.clients == 0 || _saving
            ? null
            : () => _saveTally(lines, summary.clients),
      ),
      children: [
        ...widget.header,
        const _Label(S.howManyClients),
        if (staff.isEmpty)
          EmptyCard(message: S.noStaffToday(label))
        else if (services.isEmpty)
          const EmptyCard(message: S.noServicesYet)
        else
          TutorialAnchor(
            id: 'tallyGrid',
            child: _TallyGrid(
              staff: staff,
              services: services,
              counts: _counts,
              onChanged: (staffId, serviceId, count) =>
                  setState(() => _counts[(staffId, serviceId)] = count),
            ),
          ),
        const SizedBox(height: 16),
        Section(
          children: [
            row(S.clients, '${summary.clients}'),
            row(S.sales, formatPesos(summary.sales)),
            row(
              S.staffShare(label),
              formatPesos(summary.staffShare),
              subtitle: S.addedToBalance(label),
            ),
            row(S.shopShare, formatPesos(summary.shopShare), last: true),
          ],
        ),
      ],
    );
  }
}

/// One row per staff member, one column per service, a count in each box.
/// With more services than fit, the boxes scroll sideways and the names
/// stay in place.
class _TallyGrid extends StatelessWidget {
  const _TallyGrid({
    required this.staff,
    required this.services,
    required this.counts,
    required this.onChanged,
  });

  final List<Staff> staff;
  final List<Service> services;
  final Map<(String, String), int> counts;
  final void Function(String staffId, String serviceId, int count) onChanged;

  static const double _nameWidth = 84;
  static const double _headHeight = 40;
  static const double _cellHeight = 44;
  static const double _gap = 6;
  static const double _minCell = 60;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final room = box.maxWidth - _nameWidth;
          final cell = math.max(
            _minCell,
            (room - _gap * (services.length - 1)) / services.length,
          );
          final caption = AppText.caption.copyWith(color: colors.textSecondary);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _nameWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: _headHeight),
                    for (final person in staff)
                      Container(
                        height: _cellHeight,
                        margin: const EdgeInsets.only(top: _gap),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.subhead.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: _headHeight,
                        child: Row(
                          spacing: _gap,
                          children: [
                            for (final service in services)
                              SizedBox(
                                width: cell,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      service.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: caption.copyWith(
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      formatPesos(service.price),
                                      maxLines: 1,
                                      style: caption,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      for (final person in staff)
                        Padding(
                          padding: const EdgeInsets.only(top: _gap),
                          child: Row(
                            spacing: _gap,
                            children: [
                              for (final service in services)
                                SizedBox(
                                  width: cell,
                                  height: _cellHeight,
                                  child: _CountBox(
                                    count:
                                        counts[(person.id, service.id)] ?? 0,
                                    onChanged: (count) => onChanged(
                                      person.id,
                                      service.id,
                                      count,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One box of the tally: tap it and type a number from 0 to 99.
class _CountBox extends StatefulWidget {
  const _CountBox({required this.count, required this.onChanged});

  final int count;
  final ValueChanged<int> onChanged;

  @override
  State<_CountBox> createState() => _CountBoxState();
}

class _CountBoxState extends State<_CountBox> {
  late final _text = TextEditingController(
    text: widget.count == 0 ? '' : '${widget.count}',
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = _focus.hasFocus;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focus.requestFocus,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? colors.accentSoft : colors.bgApp,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            width: 1.5,
            color: active ? colors.accent : Colors.transparent,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: CupertinoTextField(
          controller: _text,
          focusNode: _focus,
          decoration: null,
          padding: EdgeInsets.zero,
          textAlign: TextAlign.center,
          maxLines: 1,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          style: AppText.headline.copyWith(color: colors.textPrimary),
          cursorColor: colors.accent,
          placeholder: '0',
          placeholderStyle: AppText.headline.copyWith(
            color: colors.textSecondary,
          ),
          onChanged: (text) => widget.onChanged(int.tryParse(text) ?? 0),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- expense

class _ExpenseTab extends StatefulWidget {
  const _ExpenseTab({
    super.key,
    required this.day,
    required this.header,
    required this.save,
  });

  final DateTime day;
  final List<Widget> header;
  final _Save save;

  @override
  State<_ExpenseTab> createState() => _ExpenseTabState();
}

class _ExpenseTabState extends State<_ExpenseTab> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _category;
  PaymentMethod _method = PaymentMethod.cash;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _saveExpense(int amount) async {
    if (_saving) return;
    setState(() => _saving = true);
    final ledger = context.read<Ledger>();
    final expense = Expense.record(
      id: newId(),
      now: DateTime.now(),
      forDate: widget.day,
      category: _category!,
      amount: amount,
      paymentMethod: _method,
      note: _note.text,
    );
    final saved = await widget.save(
      reason: ReopenReason.addEntry,
      message: S.savedForDay(S.monthDay(widget.day)),
      change: () => ledger.addExpense(expense),
      undo: () => ledger.voidExpense(expense.id),
    );
    if (!saved && mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final names = context
        .watch<ShopConfig>()
        .categories
        .where((c) => c.active)
        .map((c) => c.name)
        .toList();
    final amount = parsePesos(_amount.text);
    final valid = amount != null && amount > 0 && _category != null;

    return _TabFrame(
      button: PrimaryButton(
        label: S.saveExpenseTo(S.monthDay(widget.day)),
        onTap: valid && !_saving ? () => _saveExpense(amount) : null,
      ),
      children: [
        ...widget.header,
        _FormCard(
          children: [
            BigAmountField(
              controller: _amount,
              onChanged: (_) => setState(() {}),
            ),
            ChipRow(
              children: [
                for (final name in names)
                  AppChip(
                    label: name,
                    selected: _category == name,
                    onTap: () => setState(() => _category = name),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SegmentedControl<PaymentMethod>(
              options: const {
                PaymentMethod.cash: S.cash,
                PaymentMethod.gcash: S.gcash,
              },
              selected: _method,
              onChanged: (method) => setState(() => _method = method),
            ),
            const SizedBox(height: 12),
            SheetField(
              label: S.noteOptional,
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------ payout and advance

enum _PayChoice { full, half, other }

class _PaymentTab extends StatefulWidget {
  const _PaymentTab({
    super.key,
    required this.day,
    required this.header,
    required this.save,
    required this.type,
  });

  final DateTime day;
  final List<Widget> header;
  final _Save save;

  /// Payout or advance.
  final PaymentType type;

  @override
  State<_PaymentTab> createState() => _PaymentTabState();
}

class _PaymentTabState extends State<_PaymentTab> {
  static const _advanceShortcuts = [20000, 50000, 100000];

  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _focus = FocusNode();
  String? _staffId;
  PaymentMethod _method = PaymentMethod.cash;
  _PayChoice? _payChoice;

  /// The advance shortcut chosen (centavos), 0 for "Other amount".
  int? _advanceChoice;
  bool _saving = false;

  bool get _isPayout => widget.type == PaymentType.payout;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The balance as it stands now. Balances are a running total, so this
  /// is what a payment dated in the past also comes out of.
  int _balance(Ledger ledger) =>
      _staffId == null ? 0 : ledger.balanceOf(_staffId!);

  void _pickStaff(String id, Ledger ledger) => setState(() {
    _staffId = id;
    if (!_isPayout) return;
    // Like the Pay Out sheet: start from the full balance.
    final balance = ledger.balanceOf(id);
    _payChoice = balance > 0 ? _PayChoice.full : _PayChoice.other;
    _amount.text = balance > 0 ? pesosInputText(balance) : '';
  });

  void _choosePay(_PayChoice choice, int balance) => setState(() {
    _payChoice = choice;
    switch (choice) {
      case _PayChoice.full:
        _amount.text = balance > 0 ? pesosInputText(balance) : '';
      case _PayChoice.half:
        // Half, rounded down to a whole peso.
        _amount.text = balance > 0
            ? pesosInputText((balance ~/ 200) * 100)
            : '';
      case _PayChoice.other:
        _amount.clear();
        _focus.requestFocus();
    }
  });

  void _chooseAdvance(int choice) => setState(() {
    _advanceChoice = choice;
    if (choice == 0) {
      _amount.clear();
      _focus.requestFocus();
    } else {
      _amount.text = pesosInputText(choice);
    }
  });

  Future<void> _savePayment(int amount) async {
    if (_saving) return;
    setState(() => _saving = true);
    final ledger = context.read<Ledger>();
    final payment = StaffPayment.record(
      id: newId(),
      now: DateTime.now(),
      forDate: widget.day,
      staffId: _staffId!,
      type: widget.type,
      amount: amount,
      // An advance is cash handed over from the drawer.
      paymentMethod: _isPayout ? _method : PaymentMethod.cash,
      note: _isPayout ? null : _reason.text,
    );
    final saved = await widget.save(
      reason: ReopenReason.addEntry,
      message: S.savedForDay(S.monthDay(widget.day)),
      change: () => ledger.addPayment(payment),
      undo: () => ledger.voidPayment(payment.id),
    );
    if (!saved && mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final config = context.watch<ShopConfig>();
    final ledger = context.watch<Ledger>();
    final label = config.settings.staffLabel;
    final staff = config.staff.where((s) => s.active).toList();
    final balance = _balance(ledger);
    final amount = parsePesos(_amount.text);
    final valid = _staffId != null && amount != null && amount > 0;
    final after = balance - (amount ?? 0);
    final dayLabel = S.monthDay(widget.day);

    return _TabFrame(
      note: _staffId == null && staff.isNotEmpty
          ? S.pickStaffFirst(label)
          : null,
      button: PrimaryButton(
        label: _isPayout ? S.savePayoutTo(dayLabel) : S.saveAdvanceTo(dayLabel),
        onTap: valid && !_saving ? () => _savePayment(amount) : null,
      ),
      children: [
        ...widget.header,
        _Label(label),
        if (staff.isEmpty)
          EmptyCard(message: S.noStaffToday(label))
        else
          TileGrid(
            tiles: [
              for (final person in staff)
                OptionTile(
                  title: person.name,
                  subtitle: formatPesos(ledger.balanceOf(person.id)),
                  selected: _staffId == person.id,
                  onTap: () => _pickStaff(person.id, ledger),
                ),
            ],
          ),
        const SizedBox(height: 16),
        _FormCard(
          children: [
            BigAmountField(
              controller: _amount,
              focusNode: _focus,
              onChanged: (_) => setState(() {
                _payChoice = _PayChoice.other;
                _advanceChoice = 0;
              }),
            ),
            if (_isPayout) ...[
              ChipRow(
                children: [
                  AppChip(
                    label: S.fullBalance,
                    selected: _payChoice == _PayChoice.full,
                    onTap: () => _choosePay(_PayChoice.full, balance),
                  ),
                  AppChip(
                    label: S.half,
                    selected: _payChoice == _PayChoice.half,
                    onTap: () => _choosePay(_PayChoice.half, balance),
                  ),
                  AppChip(
                    label: S.otherAmount,
                    selected: _payChoice == _PayChoice.other,
                    onTap: () => _choosePay(_PayChoice.other, balance),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SegmentedControl<PaymentMethod>(
                options: const {
                  PaymentMethod.cash: S.cash,
                  PaymentMethod.gcash: S.gcash,
                },
                selected: _method,
                onChanged: (method) => setState(() => _method = method),
              ),
            ] else ...[
              ChipRow(
                children: [
                  for (final shortcut in _advanceShortcuts)
                    AppChip(
                      label: formatPesos(shortcut),
                      selected: _advanceChoice == shortcut,
                      onTap: () => _chooseAdvance(shortcut),
                    ),
                  AppChip(
                    label: S.otherAmount,
                    selected: _advanceChoice == 0,
                    onTap: () => _chooseAdvance(0),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SheetField(
                label: S.reasonOptional,
                controller: _reason,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
            const SizedBox(height: 12),
            SheetValue(
              label: S.balanceAfter,
              value: _staffId == null ? '' : formatPesos(after),
              valueColor: after < 0 ? colors.moneyNegative : null,
            ),
          ],
        ),
      ],
    );
  }
}
