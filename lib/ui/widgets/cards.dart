import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'basics.dart';
import 'sheet.dart';

/// Hero card: small label, big amount, optional subline and extra content.
/// Radius 20, padding 18.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.label,
    required this.amount,
    this.amountColor,
    this.subline,
    this.trailing,
    this.child,
  });

  final String label;
  final String amount;
  final Color? amountColor;
  final String? subline;

  /// Shown at the right of the label line.
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.footnote.copyWith(color: colors.textSecondary),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: AppText.amount.copyWith(
                color: amountColor ?? colors.textPrimary,
              ),
            ),
          ),
          if (subline != null) ...[
            const SizedBox(height: 4),
            Text(
              subline!,
              style: AppText.subhead.copyWith(color: colors.textSecondary),
            ),
          ],
          ?child,
        ],
      ),
    );
  }
}

/// A row of small uppercase-label stats, used at the bottom of hero cards.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.stats});

  /// Label and value pairs.
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        for (final (label, value) in stats)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.headline.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Top bar for a pushed or full screen: a text link on the left and a
/// centered title.
class NavBar extends StatelessWidget {
  const NavBar({
    super.key,
    required this.title,
    required this.leading,
    required this.onLeading,
    this.showBackArrow = false,
  });

  final String title;
  final String leading;
  final VoidCallback onLeading;
  final bool showBackArrow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Pressable(
                onTap: onLeading,
                builder: (context, pressed) => Opacity(
                  opacity: pressed ? 0.5 : 1,
                  child: Container(
                    height: 48,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 4, right: 16),
                    child: Text(
                      showBackArrow ? '‹ $leading' : leading,
                      maxLines: 1,
                      style: AppText.body.copyWith(color: colors.accent),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            flex: 2,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.headline.copyWith(color: colors.textPrimary),
            ),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

/// A yes or no question in a bottom sheet. Pops with true when confirmed.
class ConfirmSheet extends StatelessWidget {
  const ConfirmSheet({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
  });

  final String title;
  final String body;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: title,
      children: [
        Text(
          body,
          style: AppText.body.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: confirmLabel,
          onTap: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// Two-column grid of option tiles with an 8 px gap.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        for (var i = 0; i < tiles.length; i += 2)
          Row(
            spacing: 8,
            children: [
              Expanded(child: tiles[i]),
              Expanded(
                child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox(),
              ),
            ],
          ),
      ],
    );
  }
}

/// Option tile. Selected: accent/soft fill with a 1.5 px accent outline.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? colors.accentSoft
              : (pressed ? colors.bgFill : colors.bgSurface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            width: 1.5,
            color: selected ? colors.accent : Colors.transparent,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.headline.copyWith(
                color: selected ? colors.accent : colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.footnote.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
