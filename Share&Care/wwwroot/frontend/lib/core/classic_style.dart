import 'package:flutter/material.dart';

class ClassicStyle {
    ClassicStyle._();

    // kolory (hex / rgb) - dla jasnego motywu
    static const Color my_dark_green = Color(0xFF628141);
    static const Color my_light_green = Color(0xFF8BAE66);
    static const Color my_beige = Color(0xFFEBD5AB);
    static const Color my_orange = Color(0xFFE67E22);

    // kolory (hex / rgb) - dla ciemnego motywu
    static const Color my_emerald = Color.fromARGB(255, 22, 66, 2);
    static const Color my_dark_theme = Color.fromARGB(255, 37, 37, 37);
    static const Color my_dark_beige = Color.fromARGB(255, 235, 156, 10);

    // style tekstu dla jasnego motywu
    static const TextStyle title =
            TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black);

    // style tekstu dla ciemnego motywu
    static const TextStyle title_dark_theme =
            TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white);

    // Motyw jasny aplikacji
    static ThemeData lightTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: my_dark_green,
            brightness: Brightness.light,
            primary: my_dark_green,
            secondary: my_orange,
            background: my_beige,
        ),
        scaffoldBackgroundColor: my_beige,
        appBarTheme: const AppBarTheme(
            backgroundColor: my_dark_green,
            foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: my_dark_green,
            foregroundColor: Colors.white,
        ),
    );

    // Motyw ciemny aplikacji
    static ThemeData darkTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: my_light_green,
            brightness: Brightness.dark,
            primary: my_light_green,
            secondary: my_dark_beige,
            background: my_dark_theme,
        ),
        scaffoldBackgroundColor: my_dark_theme,
        appBarTheme: const AppBarTheme(
            backgroundColor: my_light_green,
            foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: my_dark_beige,
            foregroundColor: Colors.black,
        ),
    );
}
