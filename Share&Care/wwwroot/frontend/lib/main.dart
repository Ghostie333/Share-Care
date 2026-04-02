import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'features/auth/auth_login_page.dart';
import 'features/home/home_page.dart';
import 'services/auth_service.dart';

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
          home: const _StartupScreen(),
        );
      },
    );
  }
}

class _StartupScreen extends StatefulWidget {
  const _StartupScreen();

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  AuthResult? _authResult;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (loggedIn) {
      final stored = await AuthService.getStoredAuthResult();
      setState(() {
        _authResult = stored;
        _loading = false;
      });
    } else {
      setState(() {
        _authResult = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final auth = _authResult ??
        AuthResult(
          userId: null,
          email: '',
          firstName: '',
          lastName: '',
          accessToken: null,
        );

    return HomePage(authResult: auth);
  }
}
