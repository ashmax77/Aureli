import 'package:flutter/material.dart';

/// The type scale. Eight roles, nothing heavier than bold, sentence case throughout.
/// Colours are not baked in: take them from the theme tokens.
abstract final class AppText {
  static const String family = 'Manrope';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// The one number a screen is about (e.g. what is left to spend).
  static const TextStyle hero = TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    fontFeatures: _tabular,
  );

  /// Screen titles and large section headings.
  static const TextStyle title1 = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  /// Card titles and row headings.
  static const TextStyle title2 = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  /// Field labels, chips, buttons.
  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  /// An amount inside a row or card: tabular so digits line up down a column.
  static const TextStyle figure = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
  );

  /// Any style with tabular (equal-width) digits.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: _tabular);

  /// Material's text roles mapped onto the scale, so widgets nobody styled by hand
  /// (dialogs, list tiles, fields) still match.
  static TextTheme textTheme(Color ink, Color inkSecondary) => TextTheme(
        displayLarge: hero.copyWith(color: ink),
        displayMedium: hero.copyWith(color: ink, fontSize: 28),
        displaySmall: hero.copyWith(color: ink, fontSize: 24),
        headlineLarge: title1.copyWith(color: ink, fontSize: 24),
        headlineMedium: title1.copyWith(color: ink),
        headlineSmall: title1.copyWith(color: ink, fontSize: 18),
        titleLarge: title1.copyWith(color: ink),
        titleMedium: title2.copyWith(color: ink),
        titleSmall: label.copyWith(color: ink, fontSize: 13),
        bodyLarge: body.copyWith(color: ink, fontSize: 15),
        bodyMedium: body.copyWith(color: ink),
        bodySmall: bodySmall.copyWith(color: inkSecondary),
        labelLarge: label.copyWith(color: ink, fontSize: 14),
        labelMedium: label.copyWith(color: inkSecondary),
        labelSmall: caption.copyWith(color: inkSecondary),
      );
}
