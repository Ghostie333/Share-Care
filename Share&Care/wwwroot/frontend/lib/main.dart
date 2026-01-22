import 'package:flutter/material.dart';
import 'features/auth/auth_login_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Share&Care",
      home: const LoginScreen(), // AKTUALNY ekran startowy
      // TODO: gdy dodasz HomePage, tutaj podmienisz na:
      // home: const HomePage();
    );
  }
}
