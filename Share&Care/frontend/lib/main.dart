import 'package:flutter/material.dart';
import 'screens/registration_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Share&Care",
      home: RegistrationScreen(), // ekran startowy aplikacji
    );
  }
}
