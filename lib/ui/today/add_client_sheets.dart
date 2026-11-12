import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/money.dart';
import '../state/shop_config.dart';
import '../strings.dart';
import '../widgets/basics.dart';
import '../widgets/sheet.dart';

const _gap = SizedBox(height: 12);
const _gapBeforeButton = SizedBox(height: 20);
const _decimalKeyboard = TextInputType.numberWithOptions(decimal: true);

/// Type one peso amount. Pops with centavos (more than zero).
class AmountSheet extends StatefulWidget {
  const AmountSheet({super.key, required this.title, this.initial});

  final String title;

  /// Centavos.
  final int? initial;

  @override
  State<AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<AmountSheet> {
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
      title: widget.title,
      children: [
        SheetField(
          label: S.priceLabel(pesoSign),
          controller: _amount,
          hint: '0',
          autofocus: true,
          keyboardType: _decimalKeyboard,
          inputFormatters: pesoInputFormatters,
          onChanged: (_) => setState(() {}),
        ),
        _gapBeforeButton,
        PrimaryButton(
          label: S.done,
          onTap: amount == null || amount <= 0
              ? null
              : () => Navigator.of(context).pop(amount),
        ),
      ],
    );
  }
}

/// Tip amount and how it was paid. Pops with (centavos, held by shop).
class TipSheet extends StatefulWidget {
  const TipSheet({super.key, required this.initial, required this.initialHeld});

  final int initial;
  final bool initialHeld;

  @override
  State<TipSheet> createState() => _TipSheetState();
}

class _TipSheetState extends State<TipSheet> {
  late final _amount = TextEditingController(
    text: widget.initial == 0 ? '' : pesosInputText(widget.initial),
  );
  late bool _held = widget.initialHeld;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = context.read<ShopConfig>().settings.staffLabel;
    final text = _amount.text.trim();
    // Blank means no tip.
    final amount = text.isEmpty ? 0 : parsePesos(text);
    return AppSheet(
      title: S.tip,
      children: [
        SheetField(
          label: '${S.tip} ($pesoSign)',
          controller: _amount,
          hint: '0',
          autofocus: true,
          keyboardType: _decimalKeyboard,
          inputFormatters: pesoInputFormatters,
          onChanged: (_) => setState(() {}),
        ),
        _gap,
        const SheetNote(S.tipPaidHow),
        _gap,
        SegmentedControl<bool>(
          options: const {false: S.cash, true: S.gcash},
          selected: _held,
          onChanged: (held) => setState(() => _held = held),
        ),
        _gap,
        SheetNote(_held ? S.tipGcashNote(label) : S.tipCashNote(label)),
        _gapBeforeButton,
        PrimaryButton(
          label: S.done,
          onTap: amount == null
              ? null
              : () => Navigator.of(context).pop((amount, _held)),
        ),
      ],
    );
  }
}

/// Custom service name and price. Pops with (name, centavos).
class OtherServiceSheet extends StatefulWidget {
  const OtherServiceSheet({super.key, this.initialName, this.initialPrice});

  final String? initialName;
  final int? initialPrice;

  @override
  State<OtherServiceSheet> createState() => _OtherServiceSheetState();
}

class _OtherServiceSheetState extends State<OtherServiceSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _price = TextEditingController(
    text: widget.initialPrice == null
        ? ''
        : pesosInputText(widget.initialPrice!),
  );

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    final price = parsePesos(_price.text);
    final valid = name.isNotEmpty && price != null && price > 0;
    return AppSheet(
      title: S.otherService,
      children: [
        SheetField(
          label: S.name,
          controller: _name,
          hint: S.otherNameHint,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        _gap,
        SheetField(
          label: S.priceLabel(pesoSign),
          controller: _price,
          hint: '0',
          keyboardType: _decimalKeyboard,
          inputFormatters: pesoInputFormatters,
          onChanged: (_) => setState(() {}),
        ),
        _gapBeforeButton,
        PrimaryButton(
          label: S.done,
          onTap: valid ? () => Navigator.of(context).pop((name, price)) : null,
        ),
      ],
    );
  }
}
