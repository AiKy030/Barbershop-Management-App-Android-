import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart' show newId;
import '../../domain/entries.dart';
import '../../domain/models.dart';
import '../../domain/money.dart';
import '../../domain/report.dart';
import '../../domain/sale.dart';
import '../state/ledger.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/basics.dart';
import '../widgets/day_guard.dart';
import '../widgets/sheet.dart';

const _gap = SizedBox(height: 12);
const _gapBeforeButton = SizedBox(height: 16);

enum _PayChoice { full, half, other }

/// Pay Out sheet. Figma: 6:643 (light), 6:2275 (dark).
class PayOutSheet extends StatefulWidget {
  const PayOutSheet({super.key, required this.staff});

  final Staff staff;

  @override
  State<PayOutSheet> createState() => _PayOutSheetState();
}

class _PayOutSheetState extends State<PayOutSheet> {
  late final int _balance = context.read<Ledger>().balanceOf(widget.staff.id);
  late _PayChoice _choice = _balance > 0 ? _PayChoice.full : _PayChoice.other;
  late final _amount = TextEditingController(
    text: _balance > 0 ? pesosInputText(_balance) : '',
  );
  final _focus = FocusNode();
  PaymentMethod _method = PaymentMethod.cash;
  bool _saving = false;

  /// Null means today.
  DateTime? _date;

  @override
  void dispose() {
    _amount.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _choose(_PayChoice choice) => setState(() {
    _choice = choice;
    switch (choice) {
      case _PayChoice.full:
        _amount.text = _balance > 0 ? pesosInputText(_balance) : '';
      case _PayChoice.half:
        // Half, rounded down to a whole peso.
        _amount.text = _balance > 0
            ? pesosInputText((_balance ~/ 200) * 100)
            : '';
      case _PayChoice.other:
        _amount.clear();
        _focus.requestFocus();
    }
  });

  Future<void> _confirm(int amount) async {
    if (_saving) return;
    setState(() => _saving = true);
    final ledger = context.read<Ledger>();
    final now = DateTime.now();
    final payment = StaffPayment.record(
      id: newId(),
      now: now,
      forDate: _date,
      staffId: widget.staff.id,
      type: PaymentType.payout,
      amount: amount,
      paymentMethod: _method,
    );
    final saved = await saveIntoDay(
      context,
      _date ?? now,
      () => ledger.addPayment(payment),
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _saving = false);
      return;
    }
    if (_date != null) showToast(context, S.savedForDay(S.monthDay(_date!)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amount = parsePesos(_amount.text);
    final valid = amount != null && amount > 0;
    final after = _balance - (amount ?? 0);
    return AppSheet(
      title: S.payOutTo(widget.staff.name),
      children: [
        BigAmountField(
          controller: _amount,
          focusNode: _focus,
          onChanged: (_) => setState(() => _choice = _PayChoice.other),
        ),
        ChipRow(
          children: [
            AppChip(
              label: S.fullBalance,
              selected: _choice == _PayChoice.full,
              onTap: () => _choose(_PayChoice.full),
            ),
            AppChip(
              label: S.half,
              selected: _choice == _PayChoice.half,
              onTap: () => _choose(_PayChoice.half),
            ),
            AppChip(
              label: S.otherAmount,
              selected: _choice == _PayChoice.other,
              onTap: () => _choose(_PayChoice.other),
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
        _gap,
        SheetValue(
          label: S.date,
          value: entryDateLabel(_date),
          onTap: () async {
            final picked = await pickEntryDate(context, _date);
            if (picked != null) setState(() => _date = picked.date);
          },
        ),
        _gap,
        SheetValue(
          label: S.balanceAfter,
          value: formatPesos(after),
          valueColor: after < 0 ? colors.moneyNegative : null,
        ),
        _gapBeforeButton,
        PrimaryButton(
          label: S.confirmPayout,
          onTap: valid && !_saving ? () => _confirm(amount) : null,
        ),
      ],
    );
  }
}

/// Cash Advance sheet. Figma: 6:717 (light), 6:2402 (dark).
class CashAdvanceSheet extends StatefulWidget {
  const CashAdvanceSheet({super.key, required this.staff});

  final Staff staff;

  @override
  State<CashAdvanceSheet> createState() => _CashAdvanceSheetState();
}

class _CashAdvanceSheetState extends State<CashAdvanceSheet> {
  static const _shortcuts = [20000, 50000, 100000];

  late final int _balance = context.read<Ledger>().balanceOf(widget.staff.id);
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _focus = FocusNode();

  /// The shortcut chosen (centavos), 0 for "Other amount", null for none yet.
  int? _choice;
  bool _saving = false;

  /// Null means today.
  DateTime? _date;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _choose(int choice) => setState(() {
    _choice = choice;
    if (choice == 0) {
      _amount.clear();
      _focus.requestFocus();
    } else {
      _amount.text = pesosInputText(choice);
    }
  });

  Future<void> _confirm(int amount) async {
    if (_saving) return;
    setState(() => _saving = true);
    final ledger = context.read<Ledger>();
    final now = DateTime.now();
    final payment = StaffPayment.record(
      id: newId(),
      now: now,
      forDate: _date,
      staffId: widget.staff.id,
      type: PaymentType.advance,
      amount: amount,
      // An advance is cash handed over from the drawer.
      paymentMethod: PaymentMethod.cash,
      note: _reason.text,
    );
    final saved = await saveIntoDay(
      context,
      _date ?? now,
      () => ledger.addPayment(payment),
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _saving = false);
      return;
    }
    if (_date != null) showToast(context, S.savedForDay(S.monthDay(_date!)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amount = parsePesos(_amount.text);
    final valid = amount != null && amount > 0;
    final after = _balance - (amount ?? 0);
    return AppSheet(
      title: S.cashAdvanceFor(widget.staff.name),
      children: [
        BigAmountField(
          controller: _amount,
          focusNode: _focus,
          onChanged: (_) => setState(() => _choice = 0),
        ),
        ChipRow(
          children: [
            for (final shortcut in _shortcuts)
              AppChip(
                label: formatPesos(shortcut),
                selected: _choice == shortcut,
                onTap: () => _choose(shortcut),
              ),
            AppChip(
              label: S.otherAmount,
              selected: _choice == 0,
              onTap: () => _choose(0),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SheetField(
          label: S.reasonOptional,
          controller: _reason,
          textCapitalization: TextCapitalization.sentences,
        ),
        _gap,
        SheetValue(
          label: S.date,
          value: entryDateLabel(_date),
          onTap: () async {
            final picked = await pickEntryDate(context, _date);
            if (picked != null) setState(() => _date = picked.date);
          },
        ),
        _gap,
        SheetValue(
          label: S.balanceAfter,
          value: formatPesos(after),
          valueColor: after < 0 ? colors.moneyNegative : null,
        ),
        _gapBeforeButton,
        PrimaryButton(
          label: S.confirmCashAdvance,
          onTap: valid && !_saving ? () => _confirm(amount) : null,
        ),
      ],
    );
  }
}

/// One payout, advance or adjustment, with a Void button.
class PaymentDetailSheet extends StatelessWidget {
  const PaymentDetailSheet({
    super.key,
    required this.payment,
    this.place = const ToastPlace(),
  });

  final StaffPayment payment;

  /// Where the toast goes on the screen that opened this sheet.
  final ToastPlace place;

  @override
  Widget build(BuildContext context) {
    final ledger = context.read<Ledger>();
    final (title, voidLabel) = switch (payment.type) {
      PaymentType.payout => (S.payout, S.voidPayout),
      PaymentType.advance => (S.cashAdvanceEntry, S.voidAdvance),
      PaymentType.adjustment => (S.adjustment, S.voidAdjustment),
    };
    final method = switch (payment.paymentMethod) {
      PaymentMethod.cash => S.cash,
      PaymentMethod.gcash => S.gcash,
      null => null,
    };
    return AppSheet(
      title: title,
      children: [
        SheetValue(label: S.amount, value: formatPesos(payment.amount)),
        _gap,
        SheetValue(
          label: S.date,
          value: S.shortDay(parseBusinessDate(payment.businessDate)),
        ),
        if (method != null) ...[
          _gap,
          SheetValue(label: S.paidBy, value: method),
        ],
        if (payment.note != null) ...[
          _gap,
          SheetValue(label: S.reason, value: payment.note!),
        ],
        if (payment.voided) ...[
          _gap,
          const SheetNote(S.entryWasVoided),
        ],
        _gapBeforeButton,
        if (payment.voided)
          PrimaryButton(
            label: S.restoreEntry,
            onTap: () async {
              final done = await changeEntry(
                context,
                days: [payment.businessDate],
                reason: ReopenReason.voidEntry,
                message: S.entryRestored,
                place: place,
                change: () => ledger.restorePayment(payment.id),
                undo: () => ledger.voidPayment(payment.id),
              );
              if (done && context.mounted) Navigator.of(context).pop();
            },
          )
        else
          SecondaryButton(
            label: voidLabel,
            onTap: () async {
              final done = await changeEntry(
                context,
                days: [payment.businessDate],
                reason: ReopenReason.voidEntry,
                message: S.entryVoided,
                place: place,
                change: () => ledger.voidPayment(payment.id),
                undo: () => ledger.restorePayment(payment.id),
              );
              if (done && context.mounted) Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

/// One staff member's sales on one day. Each can be voided.
class DaySalesSheet extends StatelessWidget {
  const DaySalesSheet({
    super.key,
    required this.staff,
    required this.businessDate,
  });

  final Staff staff;
  final String businessDate;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: S.salesOn(S.shortDay(parseBusinessDate(businessDate))),
      children: [
        LedgerQuery<List<Sale>>(
          queryKey: '${staff.id} $businessDate',
          load: (ledger) => ledger.salesFor(staff.id, businessDate),
          builder: (context, sales) {
            if (sales == null) return const SizedBox(height: 56);
            if (sales.isEmpty) return const SheetNote(S.noSales);
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final sale in sales) _SaleLine(sale: sale),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SaleLine extends StatelessWidget {
  const _SaleLine({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final method = sale.paymentMethod == PaymentMethod.cash ? S.cash : S.gcash;
    final tip = sale.tip == 0
        ? ''
        : ' · ${S.tip} ${formatPesos(sale.tip)} '
              '${sale.tipHeld ? S.gcash : S.cash}';
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.separator)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${sale.serviceName}  ${formatPesos(sale.price)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(color: colors.textPrimary),
                ),
                Text(
                  '${S.time(sale.createdAt)} · $method$tip',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subhead.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '+${formatPesos(sale.staffShare)}',
            style: AppText.headline.copyWith(color: colors.textPrimary),
          ),
          Pressable(
            onTap: () {
              final ledger = context.read<Ledger>();
              guardedSave(
                context,
                days: [sale.businessDate],
                reason: ReopenReason.voidEntry,
                save: () => ledger.voidSale(sale.id),
              );
            },
            builder: (context, pressed) => Opacity(
              opacity: pressed ? 0.5 : 1,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  S.voidSale,
                  style: AppText.headline.copyWith(color: colors.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
