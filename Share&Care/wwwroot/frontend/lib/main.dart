import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'features/auth/auth_login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Share&Care',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: const LoginScreen(), // AKTUALNY ekran startowy
          // TODO: gdy dodasz HomePage, tutaj podmienisz na:
          // home: const HomePage();
        );
      },
    );
  }
}
