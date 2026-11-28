import 'package:flutter/material.dart';

/// Spacing on a 4-point grid.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal padding of every screen.
  static const double screen = 20;
}

/// The only corner radii in the app.
abstract final class AppRadius {
  /// Inputs, chips, small controls.
  static const double sm = 8;

  /// Cards, panels, buttons.
  static const double md = 14;

  /// The hero card, sheets and dialogs.
  static const double lg = 24;

  static const double pill = 999;
}

/// Every colour the interface uses that is not user data (category colours are chosen by
/// the user and stay as they are). Light and dark are defined side by side here so a screen
/// never needs an `isDark ? a : b` of its own.
@immutable
class AureliTokens extends ThemeExtension<AureliTokens> {
  const AureliTokens({
    required this.canvas,
    required this.panel,
    required this.hairline,
    required this.inputFill,
    required this.glassFill,
    required this.glassEdgeHigh,
    required this.glassEdgeLow,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.inkFaint,
    required this.inkInverse,
    required this.brand,
    required this.emerald,
    required this.coral,
    required this.amber,
    required this.cobalt,
    required this.scrim,
    required this.shadow,
  });

  /// Screen background.
  final Color canvas;

  /// Solid surface for data: lists, rows, charts.
  final Color panel;

  /// 1 px borders and dividers.
  final Color hairline;
  final Color inputFill;

  /// Translucent fill of glass surfaces, and the edge that fades from top to bottom.
  final Color glassFill;
  final Color glassEdgeHigh;
  final Color glassEdgeLow;

  /// Text and icons. [inkMuted] meets 4.5:1 on [canvas] and [panel]; [inkFaint] is for
  /// disabled or decorative marks only.
  final Color ink;
  final Color inkSecondary;
  final Color inkMuted;
  final Color inkFaint;

  /// Text on a filled [ink] surface (snack bars).
  final Color inkInverse;

  /// Fill of primary buttons (always paired with white text).
  final Color brand;

  /// Income, "under plan", positive; as text or graphics on [canvas] / [panel].
  final Color emerald;

  /// Expenses, "over the limit", destructive.
  final Color coral;

  /// "Nearing the limit".
  final Color amber;

  /// Neutral information, links, second chart colour.
  final Color cobalt;

  final Color scrim;
  final Color shadow;

  static const AureliTokens light = AureliTokens(
    canvas: Color(0xFFF5F7FA),
    panel: Color(0xFFFFFFFF),
    hairline: Color(0xFFE3E8EF),
    inputFill: Color(0xFFF1F4F8),
    glassFill: Color(0xB8FFFFFF),
    glassEdgeHigh: Color(0xFFFFFFFF),
    glassEdgeLow: Color(0x33CBD5E1),
    ink: Color(0xFF0F1A2B),
    inkSecondary: Color(0xFF4A5A70),
    inkMuted: Color(0xFF5F6E84),
    inkFaint: Color(0xFF94A3B8),
    inkInverse: Color(0xFFF5F7FA),
    brand: Color(0xFF0F7A60),
    emerald: Color(0xFF0F7A60),
    coral: Color(0xFFC8443A),
    amber: Color(0xFF9A5F0E),
    cobalt: Color(0xFF2F5FD0),
    scrim: Color(0x660F1A2B),
    shadow: Color(0x0A0F1A2B),
  );

  static const AureliTokens dark = AureliTokens(
    canvas: Color(0xFF0E141F),
    panel: Color(0xFF151C28),
    hairline: Color(0x14FFFFFF),
    inputFill: Color(0x0FFFFFFF),
    glassFill: Color(0x0FFFFFFF),
    glassEdgeHigh: Color(0x3DFFFFFF),
    glassEdgeLow: Color(0x0FFFFFFF),
    ink: Color(0xFFEAF0F7),
    inkSecondary: Color(0xFF9AA7B8),
    inkMuted: Color(0xFF7A889B),
    inkFaint: Color(0xFF56637A),
    inkInverse: Color(0xFF0F1A2B),
    brand: Color(0xFF0F7A60),
    emerald: Color(0xFF34C79F),
    coral: Color(0xFFFF7A6E),
    amber: Color(0xFFF2B04E),
    cobalt: Color(0xFF7C9BFF),
    scrim: Color(0x99000000),
    shadow: Color(0x00000000),
  );

  /// Tinted background for a status chip or icon well, in the given accent.
  Color soft(Color accent, {Brightness brightness = Brightness.light}) =>
      accent.withValues(alpha: brightness == Brightness.dark ? 0.18 : 0.12);

  @override
  AureliTokens copyWith({
    Color? canvas,
    Color? panel,
    Color? hairline,
    Color? inputFill,
    Color? glassFill,
    Color? glassEdgeHigh,
    Color? glassEdgeLow,
    Color? ink,
    Color? inkSecondary,
    Color? inkMuted,
    Color? inkFaint,
    Color? inkInverse,
    Color? brand,
    Color? emerald,
    Color? coral,
    Color? amber,
    Color? cobalt,
    Color? scrim,
    Color? shadow,
  }) {
    return AureliTokens(
      canvas: canvas ?? this.canvas,
      panel: panel ?? this.panel,
      hairline: hairline ?? this.hairline,
      inputFill: inputFill ?? this.inputFill,
      glassFill: glassFill ?? this.glassFill,
      glassEdgeHigh: glassEdgeHigh ?? this.glassEdgeHigh,
      glassEdgeLow: glassEdgeLow ?? this.glassEdgeLow,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      inkInverse: inkInverse ?? this.inkInverse,
      brand: brand ?? this.brand,
      emerald: emerald ?? this.emerald,
      coral: coral ?? this.coral,
      amber: amber ?? this.amber,
      cobalt: cobalt ?? this.cobalt,
      scrim: scrim ?? this.scrim,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AureliTokens lerp(ThemeExtension<AureliTokens>? other, double t) {
    if (other is! AureliTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AureliTokens(
      canvas: l(canvas, other.canvas),
      panel: l(panel, other.panel),
      hairline: l(hairline, other.hairline),
      inputFill: l(inputFill, other.inputFill),
      glassFill: l(glassFill, other.glassFill),
      glassEdgeHigh: l(glassEdgeHigh, other.glassEdgeHigh),
      glassEdgeLow: l(glassEdgeLow, other.glassEdgeLow),
      ink: l(ink, other.ink),
      inkSecondary: l(inkSecondary, other.inkSecondary),
      inkMuted: l(inkMuted, other.inkMuted),
      inkFaint: l(inkFaint, other.inkFaint),
      inkInverse: l(inkInverse, other.inkInverse),
      brand: l(brand, other.brand),
      emerald: l(emerald, other.emerald),
      coral: l(coral, other.coral),
      amber: l(amber, other.amber),
      cobalt: l(cobalt, other.cobalt),
      scrim: l(scrim, other.scrim),
      shadow: l(shadow, other.shadow),
    );
  }
}
