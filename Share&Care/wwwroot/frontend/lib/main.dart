import 'package:flutter/material.dart';
import 'features/auth/auth_login_page.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() {
    // Sprawdź czy użytkownik jest zalogowany
    final loggedIn = AuthService.isLoggedIn();

    setState(() {
      _isLoggedIn = loggedIn;
      _isLoading = false;
    });

    // Debug log
    print('🔍 Sprawdzanie logowania: $_isLoggedIn');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Share&Care",
      home: _isLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _isLoggedIn
              ? const LoginScreen() // TODO: Zmień na HomePage() gdy będzie gotowy
              : const LoginScreen(),
    );
  }
}
