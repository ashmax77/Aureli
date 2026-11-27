import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One tab of [AnimatedNavBar]: an outline icon when idle and a filled one when selected.
class NavBarDestination {
  const NavBarDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Bottom navigation with every label always visible in full.
///
/// A tinted capsule glides to the selected tab while its icon swaps to the filled version
/// and pops slightly; the motion only answers a tap, and is skipped entirely when the
/// device asks for reduced motion.
class AnimatedNavBar extends StatelessWidget {
  const AnimatedNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
  }) : assert(destinations.length >= 2);

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavBarDestination> destinations;

  static const Color _emerald = Color(0xFF147D64);
  static const double _barHeight = 68;
  static const double _capsuleWidth = 60;
  static const double _capsuleHeight = 32;
  static const double _capsuleTop = 8;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 300);

    final background = isDark
        ? const Color(0xFF141B26).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.94);
    final hairline =
        isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0);

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0x14000000),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: background,
              border: Border(top: BorderSide(color: hairline)),
            ),
            // Inside the tinted container so tap ripples are painted above its background.
            child: Material(
              type: MaterialType.transparency,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: _barHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth =
                          constraints.maxWidth / destinations.length;
                      final capsuleLeft = currentIndex * itemWidth +
                          (itemWidth - _capsuleWidth) / 2;
                      return Stack(
                        children: [
                          AnimatedPositioned(
                            duration: duration,
                            curve: Curves.easeOutCubic,
                            left: capsuleLeft,
                            top: _capsuleTop,
                            width: _capsuleWidth,
                            height: _capsuleHeight,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _emerald.withValues(
                                    alpha: isDark ? 0.22 : 0.14),
                                borderRadius:
                                    BorderRadius.circular(_capsuleHeight / 2),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              for (var i = 0; i < destinations.length; i++)
                                Expanded(
                                  child: _NavItem(
                                    destination: destinations[i],
                                    selected: i == currentIndex,
                                    isDark: isDark,
                                    duration: duration,
                                    onTap: () {
                                      if (i != currentIndex) {
                                        HapticFeedback.selectionClick();
                                      }
                                      onTap(i);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.isDark,
    required this.duration,
    required this.onTap,
  });

  final NavBarDestination destination;
  final bool selected;
  final bool isDark;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final idleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final activeColor =
        isDark ? const Color(0xFF2CB8A0) : AnimatedNavBar._emerald;
    final color = selected ? activeColor : idleColor;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightShape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            const SizedBox(height: AnimatedNavBar._capsuleTop),
            SizedBox(
              height: AnimatedNavBar._capsuleHeight,
              child: Center(
                child: AnimatedScale(
                  scale: selected ? 1.12 : 1.0,
                  duration: duration,
                  curve: Curves.easeOutBack,
                  child: AnimatedSwitcher(
                    duration: duration,
                    switchInCurve: Curves.easeOut,
                    child: Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      key: ValueKey<bool>(selected),
                      size: 24,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              // Scales down rather than ever cutting a label off ("Transactions" is the
              // longest) on narrow phones or with a larger system font.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: duration,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                  child: Text(destination.label, maxLines: 1, softWrap: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
