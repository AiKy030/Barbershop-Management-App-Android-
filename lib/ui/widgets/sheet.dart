import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode, CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/money.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'basics.dart';

/// Opens a bottom sheet with the app's scrim. Build the content with [AppSheet].
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    elevation: 0,
    backgroundColor: Colors.transparent,
    barrierColor: context.colors.scrim,
    builder: builder,
  );
}

/// Bottom sheet body: grabber, title with Cancel, then the content. Moves
/// above the keyboard.
class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.bgFill,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Pressable(
                      onTap: () => Navigator.of(context).maybePop(),
                      builder: (context, pressed) => Opacity(
                        opacity: pressed ? 0.5 : 1,
                        child: Container(
                          height: 48,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            S.cancel,
                            style: AppText.body.copyWith(color: colors.accent),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet field: label on the left, typed value on the right.
class SheetField extends StatefulWidget {
  const SheetField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;

  /// Shown after the value, for example "%".
  final String? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  State<SheetField> createState() => _SheetFieldState();
}

class _SheetFieldState extends State<SheetField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final valueStyle = AppText.headline.copyWith(color: colors.textPrimary);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focus.requestFocus,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: colors.bgApp,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(
              widget.label,
              style: AppText.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CupertinoTextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                decoration: null,
                padding: EdgeInsets.zero,
                textAlign: TextAlign.right,
                maxLines: 1,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                textCapitalization: widget.textCapitalization,
                style: valueStyle,
                cursorColor: colors.accent,
                placeholder: widget.hint,
                placeholderStyle: AppText.body.copyWith(
                  color: colors.textSecondary,
                ),
                onChanged: widget.onChanged,
              ),
            ),
            if (widget.suffix != null) ...[
              const SizedBox(width: 2),
              Text(widget.suffix!, style: valueStyle),
            ],
          ],
        ),
      ),
    );
  }
}

/// Read-only sheet field: label on the left, value on the right. With
/// [onTap] it works as a button (for example to pick a date).
class SheetValue extends StatelessWidget {
  const SheetValue({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final box = Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.bgApp,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppText.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppText.headline.copyWith(
                color: valueColor ?? colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return box;
    return Pressable(
      onTap: onTap,
      builder: (context, pressed) =>
          Opacity(opacity: pressed ? 0.6 : 1, child: box),
    );
  }
}

/// Small secondary note under a field.
class SheetNote extends StatelessWidget {
  const SheetNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: AppText.subhead.copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}

/// Large centered peso amount that can be typed into. Used at the top of the
/// Pay Out, Cash Advance and Add Expense sheets.
class BigAmountField extends StatelessWidget {
  const BigAmountField({
    super.key,
    required this.controller,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = AppText.amount.copyWith(color: colors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(pesoSign, style: style),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28, maxWidth: 260),
            child: IntrinsicWidth(
              child: CupertinoTextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: autofocus,
                decoration: null,
                padding: EdgeInsets.zero,
                maxLines: 1,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: pesoInputFormatters,
                style: style,
                cursorColor: colors.accent,
                placeholder: '0',
                placeholderStyle: AppText.amount.copyWith(
                  color: colors.textSecondary,
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip. Selected chips use accent/soft with accent text.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      builder: (context, pressed) => Padding(
        // The chip is 36 high; the padding makes the tap target 48.
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Opacity(
          opacity: pressed ? 0.6 : 1,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? colors.accentSoft : colors.bgFill,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: AppText.footnote.copyWith(
                  color: selected ? colors.accent : colors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of chips that wraps onto more lines when needed.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, children: children);
}

/// Digits and one decimal point, for peso amounts.
final List<TextInputFormatter> pesoInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
  LengthLimitingTextInputFormatter(10),
];

/// The toast bar itself: inverted colors, optional action on the right.
class ToastBar extends StatelessWidget {
  const ToastBar({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: colors.textPrimary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.footnote.copyWith(color: colors.bgSurface),
            ),
          ),
          if (actionLabel == null)
            const SizedBox(width: 16)
          else
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  actionLabel!,
                  style: AppText.headline.copyWith(color: colors.accentSoft),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

OverlayEntry? _toastEntry;
Timer? _toastTimer;

void _dismissToast() {
  _toastTimer?.cancel();
  _toastTimer = null;
  _toastEntry?.remove();
  _toastEntry = null;
}

/// Short message near the bottom of the screen.
///
/// With [actionLabel] the toast shows a button on the right (for example
/// Undo) and stays a little longer. [aboveFooterButton] lifts it clear of a
/// screen's footer button. [aboveTabBar] false is for full screens that have
/// no tab bar.
void showToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  bool aboveFooterButton = false,
  bool aboveTabBar = true,
}) {
  _dismissToast();
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 16,
      right: 16,
      bottom:
          // Stay above the keyboard when it is showing.
          MediaQuery.viewInsetsOf(context).bottom +
          MediaQuery.paddingOf(context).bottom +
          (aboveTabBar ? 68 : 0) +
          (aboveFooterButton ? 16 + 52 + 9 : 16),
      child: ToastBar(
        message: message,
        actionLabel: actionLabel,
        onAction: () {
          _dismissToast();
          onAction?.call();
        },
      ),
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  _toastEntry = entry;
  _toastTimer = Timer(
    Duration(seconds: actionLabel == null ? 2 : 5),
    _dismissToast,
  );
}

/// Marks a widget the tutorial can point at. Outside the tutorial it does
/// nothing.
class TutorialAnchor extends StatelessWidget {
  const TutorialAnchor({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final anchors = context.getInheritedWidgetOfExactType<TutorialAnchors>();
    final key = anchors?.keys[id];
    return key == null ? child : KeyedSubtree(key: key, child: child);
  }
}

/// Provided by the tutorial: one key per anchor id.
class TutorialAnchors extends InheritedWidget {
  const TutorialAnchors({super.key, required this.keys, required super.child});

  final Map<String, GlobalKey> keys;

  @override
  bool updateShouldNotify(TutorialAnchors oldWidget) => false;
}

/// Pick one date, up to today. Pops with the date.
class DateSheet extends StatefulWidget {
  const DateSheet({super.key, required this.title, required this.initial});

  final String title;
  final DateTime initial;

  @override
  State<DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<DateSheet> {
  late DateTime _date = widget.initial;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return AppSheet(
      title: widget.title,
      children: [
        SizedBox(
          height: 180,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: _date,
            minimumYear: 2020,
            maximumDate: DateTime(now.year, now.month, now.day, 23, 59),
            onDateTimeChanged: (d) => _date = DateTime(d.year, d.month, d.day),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: S.done,
          onTap: () => Navigator.of(context).pop(_date),
        ),
      ],
    );
  }
}

/// Pick one from a short list. Pops with the value in a record, so a null
/// value ("all") can be told apart from cancelling.
class OptionSheet extends StatelessWidget {
  const OptionSheet({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;

  /// Value and label, in display order.
  final List<(String?, String)> options;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppSheet(
      title: title,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final (value, label) in options)
                Pressable(
                  onTap: () => Navigator.of(context).pop((value: value)),
                  builder: (context, pressed) => Container(
                    height: 52,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: value == selected
                          ? colors.accentSoft
                          : (pressed ? colors.bgFill : colors.bgApp),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.headline.copyWith(
                              color: value == selected
                                  ? colors.accent
                                  : colors.textPrimary,
                            ),
                          ),
                        ),
                        if (value == selected)
                          Icon(
                            LucideIcons.check,
                            size: 20,
                            color: colors.accent,
                          ),
                      ],
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
