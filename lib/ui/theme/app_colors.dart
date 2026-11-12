import 'package:flutter/material.dart';

/// Color tokens from DESIGN.md. This is the only place hex values live.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bgApp,
    required this.bgSurface,
    required this.bgFill,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnAccent,
    required this.separator,
    required this.accent,
    required this.accentSoft,
    required this.moneyPositive,
    required this.moneyNegative,
    required this.tabInactive,
    required this.chevron,
    required this.scrim,
    required this.tutorialScrim,
    required this.shadow,
  });

  /// Screen background, input fields inside sheets.
  final Color bgApp;

  /// Cards, sheets, tab bar, selected segment.
  final Color bgSurface;

  /// Segmented control track, chips, empty chart bars.
  final Color bgFill;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnAccent;
  final Color separator;
  final Color accent;
  final Color accentSoft;
  final Color moneyPositive;
  final Color moneyNegative;
  final Color tabInactive;
  final Color chevron;

  /// Behind bottom sheets.
  final Color scrim;
  final Color tutorialScrim;

  /// Drop shadow under the toast and the selected segment.
  final Color shadow;

  static const light = AppColors(
    bgApp: Color(0xFFF2F2F7),
    bgSurface: Color(0xFFFFFFFF),
    bgFill: Color(0xFFE9E9EE),
    textPrimary: Color(0xFF111114),
    textSecondary: Color(0xFF6E6E73),
    textOnAccent: Color(0xFFFFFFFF),
    separator: Color(0xFFE3E3E8),
    accent: Color(0xFF0A60E8),
    accentSoft: Color(0xFFE7F0FE),
    moneyPositive: Color(0xFF1A8F47),
    moneyNegative: Color(0xFFD93025),
    tabInactive: Color(0xFF8E8E93),
    chevron: Color(0xFFC7C7CC),
    scrim: Color(0x73000000),
    tutorialScrim: Color(0x99000000),
    shadow: Color(0x33000000),
  );

  static const dark = AppColors(
    bgApp: Color(0xFF000000),
    bgSurface: Color(0xFF1C1C1E),
    bgFill: Color(0xFF2C2C2E),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFF98989F),
    textOnAccent: Color(0xFFFFFFFF),
    separator: Color(0xFF2F2F33),
    accent: Color(0xFF3D8BFF),
    accentSoft: Color(0xFF14294D),
    moneyPositive: Color(0xFF30D158),
    moneyNegative: Color(0xFFFF5A52),
    tabInactive: Color(0xFF8E8E93),
    chevron: Color(0xFF4A4A50),
    scrim: Color(0x73000000),
    tutorialScrim: Color(0x99000000),
    shadow: Color(0x33000000),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bgApp: mix(bgApp, other.bgApp),
      bgSurface: mix(bgSurface, other.bgSurface),
      bgFill: mix(bgFill, other.bgFill),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textOnAccent: mix(textOnAccent, other.textOnAccent),
      separator: mix(separator, other.separator),
      accent: mix(accent, other.accent),
      accentSoft: mix(accentSoft, other.accentSoft),
      moneyPositive: mix(moneyPositive, other.moneyPositive),
      moneyNegative: mix(moneyNegative, other.moneyNegative),
      tabInactive: mix(tabInactive, other.tabInactive),
      chevron: mix(chevron, other.chevron),
      scrim: mix(scrim, other.scrim),
      tutorialScrim: mix(tutorialScrim, other.tutorialScrim),
      shadow: mix(shadow, other.shadow),
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
