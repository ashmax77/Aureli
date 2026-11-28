import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Theme-aware colours for widgets. Everything resolves to [AureliTokens], so light and
/// dark can never drift apart; prefer `context.tokens` in new code and treat the older
/// names below as aliases.
extension AppThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// The active tokens. Falls back to the matching built-in set when the theme was built
  /// without them (a bare `MaterialApp` in a test).
  AureliTokens get tokens =>
      Theme.of(this).extension<AureliTokens>() ??
      (isDark ? AureliTokens.dark : AureliTokens.light);

  // Texts
  Color get textPrimary => tokens.ink;
  Color get textSecondary => tokens.inkSecondary;
  Color get textMuted => tokens.inkMuted;
  Color get textLight => tokens.inkFaint;
  Color get textInverse => tokens.canvas;

  // Backgrounds & Cards
  Color get scaffoldBg => tokens.canvas;
  Color get cardBg => tokens.panel;
  Color get cardBorder => tokens.hairline;
  Color get cardLightBg => tokens.panel;

  // Inputs
  Color get inputFill => tokens.inputFill;

  // Dividers
  Color get divider => tokens.hairline;

  // Icons
  Color get iconPrimary => tokens.ink;
  Color get iconSecondary => tokens.inkSecondary;
}
