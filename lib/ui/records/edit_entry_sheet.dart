import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entries.dart';
import '../../domain/money.dart';
import '../../domain/report.dart';
import '../../domain/sale.dart';
import '../state/ledger.dart';
import '../state/shop_config.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../today/add_client_sheets.dart';
import '../widgets/basics.dart';
import '../widgets/day_guard.dart';
import '../widgets/sheet.dart';

const _gap = SizedBox(height: 12);

/// Correct, void or restore one sale. Opened by tapping a row in Records.
/// Figma: 21:4092.
class EditEntrySheet extends StatefulWidget {
  const EditEntrySheet({
    super.key,
    required this.sale,
    this.place = const ToastPlace(),
  });

  final Sale sale;

  /// Where the toast goes on the screen that opened this sheet.
  final ToastPlace place;

  @override
  State<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<EditEntrySheet> {
  static const _otherValue = '\u0000other';
  static const _customValue = '\u0000custom';

  late DateTime _date = parseBusinessDate(widget.sale.businessDate);
  late String _staffId = widget.sale.staffId;
  late ({String? id, String name}) _service = (
    id: widget.sale.serviceId,
    name: widget.sale.serviceName,
  );
  late int _price = widget.sale.price;
  late int _tip = widget.sale.tip;
  late bool _tipHeld = widget.sale.tipHeld;
  late PaymentMethod _method = widget.sale.paymentMethod;
  bool _busy = false;

  /// The sale as it would be saved now.
  Sale _edited(ShopConfig config) {
    final staff = config.staff.where((s) => s.id == _staffId).firstOrNull;
    return widget.sale.edited(
      now: DateTime.now(),
      date: _date,
      staffId: _staffId,
      staffPercent:
          staff?.effectivePercent(config.settings.defaultStaffPercent) ??
          widget.sale.staffPercent,
      service: _service,
      price: _price,
      tip: _tip,
      tipHeld: _tipHeld,
      paymentMethod: _method,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showAppSheet<DateTime>(
      context,
      (_) => DateSheet(title: S.date, initial: _date),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickStaff() async {
    final config = context.read<ShopConfig>();
    final picked = await showAppSheet<({String? value})>(
      context,
      (_) => OptionSheet(
        title: config.settings.staffLabel,
        selected: _staffId,
        options: [
          // Someone who has left stays selectable on his own old sale.
          for (final s in config.staff)
            if (s.active || s.id == widget.sale.staffId) (s.id, s.name),
        ],
      ),
    );
    final id = picked?.value;
    if (id != null) setState(() => _staffId = id);
  }

  Future<void> _pickService() async {
    final config = context.read<ShopConfig>();
    final isCustom = _service.id == null;
    final picked = await showAppSheet<({String? value})>(
      context,
      (_) => OptionSheet(
        title: S.service,
        selected: isCustom ? _customValue : _service.id,
        options: [
          // An archived service stays selectable on its own old sale.
          for (final s in config.services)
            if (s.active || s.id == widget.sale.serviceId)
              (s.id, '${s.name}  ${formatPesos(s.price)}'),
          if (isCustom) (_customValue, _service.name),
          (_otherValue, S.otherServiceOption),
        ],
      ),
    );
    final value = picked?.value;
    if (value == null || value == _customValue || !mounted) return;
    if (value == _otherValue) {
      final other = await showAppSheet<(String, int)>(
        context,
        (_) => OtherServiceSheet(
          initialName: isCustom ? _service.name : null,
          initialPrice: isCustom ? _price : null,
        ),
      );
      if (other == null) return;
      setState(() {
        _service = (id: null, name: other.$1);
        _price = other.$2;
      });
      return;
    }
    final service = config.services.firstWhere((s) => s.id == value);
    setState(() {
      _service = (id: service.id, name: service.name);
      // The service's price today; it can still be changed below.
      _price = service.price;
    });
  }

  Future<void> _editPrice() async {
    final price = await showAppSheet<int>(
      context,
      (_) => AmountSheet(title: S.price, initial: _price),
    );
    if (price != null) setState(() => _price = price);
  }

  Future<void> _editTip() async {
    final result = await showAppSheet<(int, bool)>(
      context,
      (_) => TipSheet(
        initial: _tip,
        initialHeld: _tip > 0 ? _tipHeld : _method == PaymentMethod.gcash,
      ),
    );
    if (result == null) return;
    setState(() {
      _tip = result.$1;
      _tipHeld = result.$2;
    });
  }

  /// Runs one change, then closes the sheet when it went through.
  Future<void> _run({
    required Iterable<String> days,
    required ReopenReason reason,
    required String message,
    required Future<void> Function() change,
    required Future<void> Function() undo,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final done = await changeEntry(
      context,
      days: days,
      reason: reason,
      message: message,
      change: change,
      undo: undo,
      place: widget.place,
    );
    if (!mounted) return;
    if (done) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final config = context.watch<ShopConfig>();
    final ledger = context.read<Ledger>();
    final original = widget.sale;
    final staffName =
        config.staff.where((s) => s.id == _staffId).firstOrNull?.name ?? '';
    final tipText = _tip == 0
        ? formatPesos(0)
        : '${formatPesos(_tip)} · ${_tipHeld ? S.gcash : S.cash}';

    if (original.voided) {
      return AppSheet(
        title: S.editEntry,
        children: [
          SheetValue(label: S.date, value: S.shortDay(_date)),
          _gap,
          SheetValue(label: config.settings.staffLabel, value: staffName),
          _gap,
          SheetValue(label: S.service, value: _service.name),
          _gap,
          SheetValue(label: S.price, value: formatPesos(_price)),
          _gap,
          SheetValue(label: S.tip, value: tipText),
          _gap,
          SheetValue(
            label: S.paidBy,
            value: _method == PaymentMethod.cash ? S.cash : S.gcash,
          ),
          _gap,
          const SheetNote(S.entryWasVoided),
          const SizedBox(height: 16),
          PrimaryButton(
            label: S.restoreEntry,
            onTap: _busy
                ? null
                : () => _run(
                    days: [original.businessDate],
                    reason: ReopenReason.voidEntry,
                    message: S.entryRestored,
                    change: () => ledger.restoreSale(original.id),
                    undo: () => ledger.voidSale(original.id),
                  ),
          ),
        ],
      );
    }

    final edited = _edited(config);
    final changed = !edited.sameValuesAs(original);

    return AppSheet(
      title: S.editEntry,
      children: [
        SheetValue(
          label: S.date,
          value: S.shortDay(_date),
          onTap: _pickDate,
        ),
        _gap,
        SheetValue(
          label: config.settings.staffLabel,
          value: staffName,
          onTap: _pickStaff,
        ),
        _gap,
        SheetValue(
          label: S.service,
          value: _service.name,
          onTap: _pickService,
        ),
        _gap,
        SheetValue(
          label: S.price,
          value: formatPesos(_price),
          onTap: _editPrice,
        ),
        _gap,
        SheetValue(label: S.tip, value: tipText, onTap: _editTip),
        _gap,
        SegmentedControl<PaymentMethod>(
          options: const {
            PaymentMethod.cash: S.cash,
            PaymentMethod.gcash: S.gcash,
          },
          selected: _method,
          onChanged: (method) => setState(() => _method = method),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: S.saveChanges,
          onTap: !changed || _busy
              ? null
              : () => _run(
                  days: [original.businessDate, edited.businessDate],
                  reason: ReopenReason.editEntry,
                  message: S.entryUpdated,
                  change: () => ledger.updateSale(edited),
                  undo: () => ledger.updateSale(original),
                ),
        ),
        const SizedBox(height: 4),
        Pressable(
          onTap: _busy
              ? null
              : () => _run(
                  days: [original.businessDate],
                  reason: ReopenReason.voidEntry,
                  message: S.entryVoided,
                  change: () => ledger.voidSale(original.id),
                  undo: () => ledger.restoreSale(original.id),
                ),
          builder: (context, pressed) => Opacity(
            opacity: pressed ? 0.5 : 1,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Text(
                S.voidThisEntry,
                style: AppText.headline.copyWith(color: colors.moneyNegative),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
