import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._internal();
  factory ThemeController() => instance;
  ThemeController._internal() {
    _loadSavedTheme();
  }

  static const String _prefKeyThemeMode = 'hiroshima_pos_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  bool _hasManualOverride = false;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void resetForTesting() {
    _themeMode = ThemeMode.system;
    _hasManualOverride = false;
  }

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_prefKeyThemeMode);
      if (_hasManualOverride) return;
      if (modeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else if (modeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _hasManualOverride = true;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mode == ThemeMode.light) {
        await prefs.setString(_prefKeyThemeMode, 'light');
      } else if (mode == ThemeMode.dark) {
        await prefs.setString(_prefKeyThemeMode, 'dark');
      } else {
        await prefs.remove(_prefKeyThemeMode);
      }
    } catch (_) {}
  }

  Future<void> toggleTheme(BuildContext context) async {
    final currentBrightness = MediaQuery.platformBrightnessOf(context);
    final currentlyDark = _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system && currentBrightness == Brightness.dark);
    await setThemeMode(currentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}
