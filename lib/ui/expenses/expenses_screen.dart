import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart' show newId;
import '../../domain/entries.dart';
import '../../domain/money.dart';
import '../../domain/report.dart';
import '../../domain/sale.dart';
import '../state/ledger.dart';
import '../state/shop_config.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/basics.dart';
import '../widgets/cards.dart';
import '../widgets/day_guard.dart';
import '../widgets/sheet.dart';

String _methodLabel(PaymentMethod method) =>
    method == PaymentMethod.cash ? S.cash : S.gcash;

/// Expenses tab: this month's total and list.
/// Figma: 3:428 (light), 6:1797 (dark).
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ledger = context.watch<Ledger>();
    final all = ledger.monthExpenses;
    final today = all.where((e) => e.businessDate == ledger.todayKey).toList();
    final earlier = all
        .where((e) => e.businessDate != ledger.todayKey)
        .toList();
    int total(Iterable<Expense> list) =>
        list.fold(0, (sum, e) => sum + e.amount);

    void open(Expense expense) =>
        showAppSheet<void>(context, (_) => ExpenseSheet(expense: expense));

    List<Widget> rows(List<Expense> list, {required bool showDate}) => [
      for (var i = 0; i < list.length; i++)
        AppRow(
          title: list[i].title,
          subtitle: showDate
              ? '${S.monthDay(parseBusinessDate(list[i].businessDate))} · '
                    '${_methodLabel(list[i].paymentMethod)}'
              : '${list[i].category} · ${_methodLabel(list[i].paymentMethod)}',
          value: formatPesos(list[i].amount),
          valueColor: colors.textPrimary,
          isLast: i == list.length - 1,
          onTap: () => open(list[i]),
        ),
    ];

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
                  child: Text(
                    S.monthYear(ledger.date).toUpperCase(),
                    style: AppText.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    S.expenses,
                    style: AppText.largeTitle.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                HeroCard(
                  label: S.thisMonth,
                  amount: formatPesos(total(all)),
                  subline:
                      '${S.expenseCount(all.length)}  ·  '
                      '${S.todayAmount(formatPesos(total(today)))}',
                ),
                const SizedBox(height: 16),
                if (all.isEmpty) const EmptyCard(message: S.noExpenses),
                if (today.isNotEmpty)
                  Section(
                    label: S.today,
                    children: rows(today, showDate: false),
                  ),
                if (today.isNotEmpty && earlier.isNotEmpty)
                  const SizedBox(height: 16),
                if (earlier.isNotEmpty)
                  Section(
                    label: S.earlier,
                    children: rows(earlier, showDate: true),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TutorialAnchor(
              id: 'addExpense',
              child: PrimaryButton(
                label: S.addExpense,
                onTap: () =>
                    showAppSheet<void>(context, (_) => const ExpenseSheet()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Add an expense, or edit or void one when [expense] is given.
/// Figma: 6:785 (light), 6:2529 (dark).
class ExpenseSheet extends StatefulWidget {
  const ExpenseSheet({
    super.key,
    this.expense,
    this.place = const ToastPlace(aboveFooterButton: true),
  });

  final Expense? expense;

  /// Where the toast goes on the screen that opened this sheet.
  final ToastPlace place;

  @override
  State<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<ExpenseSheet> {
  late final _amount = TextEditingController(
    text: widget.expense == null ? '' : pesosInputText(widget.expense!.amount),
  );
  late final _note = TextEditingController(text: widget.expense?.note);
  late String? _category = widget.expense?.category;
  late PaymentMethod _method =
      widget.expense?.paymentMethod ?? PaymentMethod.cash;
  bool _saving = false;

  /// Null means today. An expense being edited starts on its own day.
  late DateTime? _date = widget.expense == null
      ? null
      : parseBusinessDate(widget.expense!.businessDate);

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(int amount) async {
    if (_saving) return;
    setState(() => _saving = true);
    final ledger = context.read<Ledger>();
    final existing = widget.expense;
    final note = _note.text.trim();
    if (existing == null) {
      final now = DateTime.now();
      final expense = Expense.record(
        id: newId(),
        now: now,
        forDate: _date,
        category: _category!,
        amount: amount,
        paymentMethod: _method,
        note: note,
      );
      final saved = await saveIntoDay(
        context,
        _date ?? now,
        () => ledger.addExpense(expense),
      );
      if (!mounted) return;
      if (!saved) {
        setState(() => _saving = false);
        return;
      }
      if (_date != null) {
        showToast(
          context,
          S.savedForDay(S.monthDay(_date!)),
          aboveFooterButton: true,
        );
      }
    } else {
      final category = _category!;
      final method = _method;
      final newDay = entryDateOf(DateTime.now(), _date);
      final saved = await changeEntry(
        context,
        days: [existing.businessDate, newDay],
        reason: ReopenReason.editEntry,
        message: S.entryUpdated,
        place: widget.place,
        change: () => ledger.updateExpense(
          existing.id,
          category: category,
          amount: amount,
          paymentMethod: method,
          note: note.isEmpty ? null : note,
          businessDate: newDay,
        ),
        undo: () => ledger.updateExpense(
          existing.id,
          category: existing.category,
          amount: existing.amount,
          paymentMethod: existing.paymentMethod,
          note: existing.note,
          businessDate: existing.businessDate,
        ),
      );
      if (!mounted) return;
      if (!saved) {
        setState(() => _saving = false);
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.expense;
    final names = context
        .read<ShopConfig>()
        .categories
        .where((c) => c.active)
        .map((c) => c.name)
        .toList();
    // Keep an archived category selectable while editing an old expense.
    if (existing != null && !names.contains(existing.category)) {
      names.add(existing.category);
    }
    final amount = parsePesos(_amount.text);
    final valid = amount != null && amount > 0 && _category != null;

    if (existing != null && existing.voided) {
      final ledger = context.read<Ledger>();
      return AppSheet(
        title: S.editExpense,
        children: [
          SheetValue(label: S.amount, value: formatPesos(existing.amount)),
          const SizedBox(height: 12),
          SheetValue(label: S.category, value: existing.category),
          const SizedBox(height: 12),
          SheetValue(
            label: S.date,
            value: S.shortDay(parseBusinessDate(existing.businessDate)),
          ),
          const SizedBox(height: 12),
          SheetValue(
            label: S.paidBy,
            value: _methodLabel(existing.paymentMethod),
          ),
          if (existing.note != null) ...[
            const SizedBox(height: 12),
            SheetValue(label: S.note, value: existing.note!),
          ],
          const SizedBox(height: 12),
          const SheetNote(S.entryWasVoided),
          const SizedBox(height: 16),
          PrimaryButton(
            label: S.restoreEntry,
            onTap: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    final done = await changeEntry(
                      context,
                      days: [existing.businessDate],
                      reason: ReopenReason.voidEntry,
                      message: S.entryRestored,
                      place: widget.place,
                      change: () => ledger.restoreExpense(existing.id),
                      undo: () => ledger.voidExpense(existing.id),
                    );
                    if (!context.mounted) return;
                    if (done) {
                      Navigator.of(context).pop();
                    } else {
                      setState(() => _saving = false);
                    }
                  },
          ),
        ],
      );
    }

    return AppSheet(
      title: existing == null ? S.addExpense : S.editExpense,
      children: [
        BigAmountField(
          controller: _amount,
          autofocus: existing == null,
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
        SheetValue(
          label: S.date,
          value: existing == null
              ? entryDateLabel(_date)
              : S.shortDay(_date!),
          onTap: () async {
            if (existing == null) {
              final picked = await pickEntryDate(context, _date);
              if (picked != null) setState(() => _date = picked.date);
              return;
            }
            final picked = await showAppSheet<DateTime>(
              context,
              (_) => DateSheet(title: S.date, initial: _date!),
            );
            if (picked != null) setState(() => _date = picked);
          },
        ),
        const SizedBox(height: 12),
        SheetField(
          label: S.noteOptional,
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: S.saveExpense,
          onTap: valid && !_saving ? () => _save(amount) : null,
        ),
        if (existing != null) ...[
          const SizedBox(height: 12),
          SecondaryButton(
            label: S.voidExpense,
            onTap: () async {
              final ledger = context.read<Ledger>();
              final done = await changeEntry(
                context,
                days: [existing.businessDate],
                reason: ReopenReason.voidEntry,
                message: S.entryVoided,
                place: widget.place,
                change: () => ledger.voidExpense(existing.id),
                undo: () => ledger.restoreExpense(existing.id),
              );
              if (done && context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}
