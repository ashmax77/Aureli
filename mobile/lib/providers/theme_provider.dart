import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which theme the app uses. Follows the phone's light/dark setting until the user picks
/// one explicitly.
class ThemeProvider extends ChangeNotifier {
  static const String _themePrefKey = 'aureli_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get followsSystem => _themeMode == ThemeMode.system;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  static ThemeMode _fromStored(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _toStored(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = _fromStored(prefs.getString(_themePrefKey));
      if (loaded != _themeMode) {
        _themeMode = loaded;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Failed to load theme preference: $e");
    }
  }

  /// Flips between light and dark. [currentBrightness] is what is on screen now, which is
  /// what to flip when the app is following the system.
  Future<void> toggleTheme([Brightness? currentBrightness]) async {
    final showingDark = followsSystem
        ? currentBrightness == Brightness.dark
        : _themeMode == ThemeMode.dark;
    await setThemeMode(showingDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, _toStored(mode));
    } catch (e) {
      if (kDebugMode) debugPrint("Failed to save theme preference: $e");
    }
  }
}
