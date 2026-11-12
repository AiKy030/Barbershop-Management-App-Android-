import 'package:flutter/widgets.dart';

/// Type scale from DESIGN.md. Colors are applied where the text is used.
abstract final class AppText {
  static const String fontFamily = 'Inter';

  static TextStyle _style(
    double size,
    double lineHeight,
    FontWeight weight,
    double spacing,
  ) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: spacing,
    decoration: TextDecoration.none,
  );

  /// Hero money figures.
  static final amount = _style(40, 46, FontWeight.w700, -1);

  /// Screen titles.
  static final largeTitle = _style(32, 38, FontWeight.w700, -0.6);

  /// Sheet titles, stat tile values.
  static final title = _style(20, 26, FontWeight.w600, -0.3);

  /// Row values, button labels, chip names.
  static final headline = _style(16, 22, FontWeight.w600, -0.2);

  /// Row titles, body text.
  static final body = _style(16, 22, FontWeight.w400, -0.2);

  /// Row subtitles, hero sublines.
  static final subhead = _style(14, 20, FontWeight.w400, -0.1);

  /// Tile labels, segment labels, chips.
  static final footnote = _style(13, 18, FontWeight.w500, 0);

  /// Section headers (uppercase), tab labels.
  static final caption = _style(11, 14, FontWeight.w500, 0.1);
}
