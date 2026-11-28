import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// A thin rounded progress bar. [ratio] is clamped to 0..1; the track is a faint wash of
/// the ink colour so it reads on a panel, on glass and in both themes.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.ratio,
    required this.color,
    this.height = 6,
  });

  final double ratio;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: t.ink.withValues(alpha: 0.10)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio.isNaN ? 0 : ratio.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
