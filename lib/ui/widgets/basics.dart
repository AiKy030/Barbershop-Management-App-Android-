import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Tap target with a pressed state and no Material ripple.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.onTap, required this.builder});

  final VoidCallback? onTap;
  final Widget Function(BuildContext context, bool pressed) builder;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: widget.builder(context, _pressed),
      ),
    );
  }
}

/// Screen frame: app background, system bar colors, optional bottom bar.
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.body, this.bottomBar});

  final Widget body;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconBrightness = dark ? Brightness.light : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: bottomBar == null
            ? colors.bgApp
            : colors.bgSurface,
        systemNavigationBarIconBrightness: iconBrightness,
      ),
      child: Scaffold(
        backgroundColor: colors.bgApp,
        body: body,
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}

/// Large bold screen title, with an optional back link above it.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.backLabel});

  final String title;

  /// When set, shows a back link with this label.
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (backLabel != null)
          Pressable(
            onTap: () => Navigator.of(context).maybePop(),
            builder: (context, pressed) => Opacity(
              opacity: pressed ? 0.5 : 1,
              child: SizedBox(
                height: 48,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.chevronLeft,
                      size: 24,
                      color: colors.accent,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      backLabel!,
                      style: AppText.body.copyWith(color: colors.accent),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(left: 4, top: backLabel == null ? 8 : 0),
          child: Text(
            title,
            style: AppText.largeTitle.copyWith(color: colors.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// Uppercase label over a rounded card of rows.
class Section extends StatelessWidget {
  const Section({super.key, this.label, required this.children});

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              label!.toUpperCase(),
              style: AppText.caption.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: colors.bgSurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// List row: optional avatar, title, optional subtitle, value and chevron.
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.valueColor,
    this.avatarInitial,
    this.showChevron = true,
    this.isLast = false,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Color? valueColor;
  final String? avatarInitial;
  final bool showChevron;

  /// The last row in a card has no separator.
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.fromLTRB(16, 11, 14, 11),
        decoration: BoxDecoration(
          color: pressed ? colors.bgFill : colors.bgSurface,
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: colors.separator)),
        ),
        child: Row(
          children: [
            if (avatarInitial != null) ...[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  avatarInitial!,
                  style: AppText.footnote.copyWith(color: colors.accent),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(color: colors.textPrimary),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.subhead.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.headline.copyWith(
                    color: valueColor ?? colors.textSecondary,
                  ),
                ),
              ),
            ],
            if (showChevron) ...[
              const SizedBox(width: 12),
              Icon(LucideIcons.chevronRight, size: 16, color: colors.chevron),
            ],
          ],
        ),
      ),
    );
  }
}

/// Plain message inside a card, for empty lists.
class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Section(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}

enum _ButtonKind { primary, secondary }

/// Accent fill, on-accent label. 52 high.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onTap});

  final String label;

  /// Null disables the button.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) =>
      _AppButton(label: label, onTap: onTap, kind: _ButtonKind.primary);
}

/// Accent/soft fill, accent label. 52 high.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) =>
      _AppButton(label: label, onTap: onTap, kind: _ButtonKind.secondary);
}

class _AppButton extends StatelessWidget {
  const _AppButton({
    required this.label,
    required this.onTap,
    required this.kind,
  });

  final String label;
  final VoidCallback? onTap;
  final _ButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final primary = kind == _ButtonKind.primary;
    return Pressable(
      onTap: onTap,
      builder: (context, pressed) => Opacity(
        opacity: onTap == null ? 0.4 : (pressed ? 0.7 : 1),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: primary ? colors.accent : colors.accentSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.headline.copyWith(
              color: primary ? colors.textOnAccent : colors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS-style segmented control. Track uses bg/fill, selection uses bg/surface.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// Value to label, in display order.
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.bgFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: Pressable(
                onTap: () => onChanged(entry.key),
                builder: (context, pressed) {
                  final isSelected = entry.key == selected;
                  return Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? colors.bgSurface : null,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colors.shadow.withValues(alpha: 0.1),
                                offset: const Offset(0, 1),
                                blurRadius: 3,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      entry.value,
                      style: AppText.footnote.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
