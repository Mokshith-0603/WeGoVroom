import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeProvider extends ChangeNotifier {
  ThemeModeProvider(this._preferences)
    : _themeMode = _preferences.getBool(_darkModeKey) == true
          ? ThemeMode.dark
          : ThemeMode.light;

  static const _darkModeKey = 'dark_mode_enabled';

  final SharedPreferences _preferences;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void setDarkMode(bool enabled) {
    final nextMode = enabled ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == nextMode) return;
    _themeMode = nextMode;
    notifyListeners();
    unawaited(_preferences.setBool(_darkModeKey, enabled));
  }
}
