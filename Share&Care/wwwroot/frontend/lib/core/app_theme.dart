import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'classic_style.dart';

/// Globalna kontrola motywu aplikacji.
class AppTheme {
  AppTheme._();

  static const String _themeModeKey = 'settings.theme_mode';
  static const String _textScaleKey = 'settings.text_scale';
  static const String _reduceMotionKey = 'settings.reduce_motion';
  static const String _highContrastKey = 'settings.high_contrast';

  /// Aktualny tryb motywu (jasny / ciemny).
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  /// Skalowanie tekstu w całej aplikacji.
  static final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);

  /// Ogranicza animacje w aplikacji.
  static final ValueNotifier<bool> reduceMotion = ValueNotifier<bool>(false);

  /// Zwiększa kontrast wybranych elementów interfejsu.
  static final ValueNotifier<bool> highContrast = ValueNotifier<bool>(false);

  static ThemeData get lightTheme => _buildTheme(ClassicStyle.lightTheme);
  static ThemeData get darkTheme => _buildTheme(ClassicStyle.darkTheme);

  static ThemeData _buildTheme(ThemeData base) {
    if (!highContrast.value) return base;

    return base.copyWith(
      cardColor: base.brightness == Brightness.dark
          ? Colors.black
          : Colors.white,
      dividerColor: base.brightness == Brightness.dark
          ? Colors.white70
          : Colors.black54,
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: base.brightness == Brightness.dark
                ? Colors.white70
                : Colors.black54,
          ),
        ),
      ),
    );
  }

  static Future<void> loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedMode = prefs.getString(_themeModeKey);
    final savedScale = prefs.getDouble(_textScaleKey);
    final savedReduceMotion = prefs.getBool(_reduceMotionKey);
    final savedHighContrast = prefs.getBool(_highContrastKey);

    if (savedMode == 'dark') {
      themeMode.value = ThemeMode.dark;
    } else {
      themeMode.value = ThemeMode.light;
    }

    if (savedScale != null && savedScale >= 0.9 && savedScale <= 1.4) {
      textScale.value = savedScale;
    }
    reduceMotion.value = savedReduceMotion ?? false;
    highContrast.value = savedHighContrast ?? false;
  }

  /// Ustawia tryb ciemny / jasny.
  static void setDarkMode(bool isDark) {
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    _saveThemeMode();
  }

  static void setTextScale(double scale) {
    textScale.value = scale;
    _saveTextScale();
  }

  static void setReduceMotion(bool enabled) {
    reduceMotion.value = enabled;
    _saveReduceMotion();
  }

  static void setHighContrast(bool enabled) {
    highContrast.value = enabled;
    _saveHighContrast();
  }

  static Future<void> _saveThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeModeKey,
      themeMode.value == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  static Future<void> _saveTextScale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, textScale.value);
  }

  static Future<void> _saveReduceMotion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reduceMotionKey, reduceMotion.value);
  }

  static Future<void> _saveHighContrast() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highContrastKey, highContrast.value);
  }
}
