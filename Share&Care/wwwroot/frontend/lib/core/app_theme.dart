import 'package:flutter/material.dart';

import 'classic_style.dart';

/// Globalna kontrola motywu aplikacji.
class AppTheme {
  AppTheme._();

  /// Aktualny tryb motywu (jasny / ciemny).
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static ThemeData get lightTheme => ClassicStyle.lightTheme;
  static ThemeData get darkTheme => ClassicStyle.darkTheme;

  /// Ustawia tryb ciemny / jasny.
  static void setDarkMode(bool isDark) {
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}
