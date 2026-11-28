import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// How a [GlassCard] is drawn.
enum GlassVariant {
  /// Solid surface with a hairline border. For data: lists, rows, charts. No blur, so a
  /// long scrolling list stays cheap and its numbers sit on a stable background.
  panel,

  /// Frosted, translucent surface with a crisp top-lit edge. For layers that float over
  /// content: the hero summary, sheets.
  glass,

  /// [glass], tinted with [GlassCard.tint] to carry a state (on plan, nearing, over).
  hero,
}

/// The app's surface. Defaults to a flat [GlassVariant.panel]; ask for glass sparingly,
/// since every blurred surface costs a backdrop filter.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.variant = GlassVariant.panel,
    this.tint,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  final Widget child;
  final GlassVariant variant;

  /// The state colour of a [GlassVariant.hero] card.
  final Color? tint;

  /// Defaults to [AppRadius.md] for a panel and [AppRadius.lg] for glass and hero.
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isDark = context.isDark;
    final radius = borderRadius ??
        (variant == GlassVariant.panel ? AppRadius.md : AppRadius.lg);
    final shape = BorderRadius.circular(radius);

    if (variant == GlassVariant.panel) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: t.panel,
          borderRadius: shape,
          border: Border.all(color: t.hairline),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: t.shadow,
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: child,
      );
    }

    final accent = variant == GlassVariant.hero ? tint : null;
    final fill = accent == null
        ? t.glassFill
        : Color.alphaBlend(
            accent.withValues(alpha: isDark ? 0.14 : 0.10), t.glassFill);
    final edgeHigh = accent == null
        ? t.glassEdgeHigh
        : Color.lerp(t.glassEdgeHigh, accent, 0.55)!;
    final edgeLow = accent == null
        ? t.glassEdgeLow
        : Color.lerp(t.glassEdgeLow, accent, 0.25)!;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: t.shadow,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: CustomPaint(
            foregroundPainter: _EdgePainter(
              radius: radius,
              high: edgeHigh,
              low: edgeLow,
            ),
            child: Container(
              padding: padding,
              color: fill,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A 1 px outline that is bright along the top and fades towards the bottom, as if lit
/// from above. It is what keeps a translucent surface crisp.
class _EdgePainter extends CustomPainter {
  const _EdgePainter({
    required this.radius,
    required this.high,
    required this.low,
  });

  final double radius;
  final Color high;
  final Color low;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [high, low],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius - 0.5)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.radius != radius || old.high != high || old.low != low;
}

/// Screen background: the canvas colour plus two very soft, static tonal fields, so glass
/// layered above it has something to refract. Cheap (two gradients, no blur, no animation).
class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isDark = context.isDark;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: t.canvas),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-1.0, -1.05),
                radius: 1.15,
                colors: [
                  t.cobalt.withValues(alpha: isDark ? 0.14 : 0.07),
                  t.cobalt.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(1.0, 1.05),
                radius: 1.0,
                colors: [
                  t.emerald.withValues(alpha: isDark ? 0.12 : 0.06),
                  t.emerald.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}
