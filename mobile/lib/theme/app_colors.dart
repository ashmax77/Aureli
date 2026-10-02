import 'package:flutter/material.dart';

extension AppThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Texts
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? Colors.white70 : const Color(0xFF475569);
  Color get textMuted => isDark ? Colors.white54 : const Color(0xFF94A3B8);
  Color get textLight => isDark ? Colors.white38 : const Color(0xFFCBD5E1);
  
  Color get textInverse => isDark ? const Color(0xFF0F172A) : Colors.white;

  // Backgrounds & Cards
  Color get scaffoldBg => Theme.of(this).scaffoldBackgroundColor;
  Color get cardBg => isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
  Color get cardBorder => isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0);
  Color get cardLightBg => isDark ? const Color(0xFF141B26) : Colors.white;

  // Inputs
  Color get inputFill => isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9);
  
  // Dividers
  Color get divider => isDark ? Colors.white24 : Colors.black12;
  
  // Icons
  Color get iconPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get iconSecondary => isDark ? Colors.white70 : const Color(0xFF334155);
}
