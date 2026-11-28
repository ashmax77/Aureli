import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

/// One choice in a [SegmentToggle].
class Segment<T> {
  const Segment({required this.value, required this.label, this.color});

  final T value;
  final String label;

  /// Fill when selected; defaults to the brand colour.
  final Color? color;
}

/// A compact two-to-four way switch: a quiet track with the selected option lifted onto
/// a filled pill. Replaces rows of choice chips for mutually exclusive options.
class SegmentToggle<T> extends StatelessWidget {
  const SegmentToggle({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<Segment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.hairline),
      ),
      child: Row(
        children: [
          for (final s in segments)
            Expanded(
              child: Semantics(
                button: true,
                selected: s.value == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(s.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    constraints: const BoxConstraints(minHeight: 40),
                    decoration: BoxDecoration(
                      color: s.value == selected
                          ? (s.color ?? t.brand)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md - 3),
                    ),
                    child: Text(
                      s.label,
                      style: AppText.label.copyWith(
                        fontSize: 14,
                        color:
                            s.value == selected ? t.inkInverse : t.inkSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
