import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class AuthResult {
  final String? userId;
  final String email;
  final String firstName;
  final String lastName;
  final String? accessToken; // for JWT scenario

  AuthResult({
    this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.accessToken,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      userId: json['userId'] as String?,
      email: json['email'] as String? ?? '',
      firstName: json['name'] as String? ?? json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      accessToken: json['access_token'] as String?,
    );
  }
}

class AuthService {
  // rejestracja użytkownika w backendzie
  static Future<void> registerUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    required String birthday,
    String? city,
    String? postalCode,
  }) async {
    final body = <String, dynamic>{
      'Email': email,
      'Password': password,
      'FirstName': firstName,
      'LastName': lastName,
      'PhoneNumber': phoneNumber,
      'Birthday': birthday,
      'City': city,
      'PostalCode': postalCode,
    };

    final http.Response res =
        await ApiService.postJson('/UserRegistration/user-registry', body);

    if (res.statusCode == 200) {
      return;
    } else if (res.statusCode == 409) {
      throw Exception('Email już istnieje');
    } else {
      throw Exception('Błąd serwera: ${res.statusCode} ${res.body}');
    }
  }

  // logowanie za pomocą ciasteczek (scenariusz WWW)
  static Future<AuthResult> loginCookie({
    required String email,
    required String password,
  }) async {
    final body = <String, dynamic>{
      'Email': email,
      'Password': password,
    };

    final http.Response res =
        await ApiService.postJson('/UserLogin/login-cookie', body);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return AuthResult.fromJson(decoded);
    } else {
      throw Exception('Nieprawidłowy email lub hasło');
    }
  }

  // logowanie JWT (np. dla mobile); na razie nieużywane, ale gotowe
  static Future<AuthResult> loginJwt({
    required String email,
    required String password,
  }) async {
    final body = <String, dynamic>{
      'Email': email,
      'Password': password,
    };

    final http.Response res =
        await ApiService.postJson('/UserLogin/login-jwt', body);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return AuthResult.fromJson(decoded);
    } else {
      throw Exception('Nieprawidłowy email lub hasło');
    }
  }
}
