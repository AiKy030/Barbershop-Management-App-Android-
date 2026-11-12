import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: AppText.fontFamily,
    scaffoldBackgroundColor: colors.bgApp,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: brightness,
        ).copyWith(
          primary: colors.accent,
          onPrimary: colors.textOnAccent,
          surface: colors.bgSurface,
          onSurface: colors.textPrimary,
        ),
    // No Material ripples anywhere; widgets draw their own pressed state.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.accent,
      selectionColor: colors.accentSoft,
      selectionHandleColor: colors.accent,
    ),
    extensions: [colors],
  );
}
