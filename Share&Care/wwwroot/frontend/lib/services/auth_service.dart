import 'dart:convert';
import 'dart:html' as html;

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
        await ApiService.postJson('/UserRegistration/user-registry', body, includeAuth: false);

    if (res.statusCode == 200) {
      // Backend zwraca token po rejestracji
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final token = decoded['access_token'] as String?;

      // ZAPISZ TOKEN do localStorage
      if (token != null) {
        html.window.localStorage['jwt_token'] = token;
      }

      return;
    } else if (res.statusCode == 409) {
      throw Exception('Email już istnieje');
    } else {
      throw Exception('Błąd serwera: ${res.statusCode} ${res.body}');
    }
  }

  // logowanie JWT (Web + Mobile)
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final body = <String, dynamic>{
      'Email': email,
      'Password': password,
    };

    final http.Response res =
        await ApiService.postJson('/UserLogin/login', body, includeAuth: false);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final token = decoded['access_token'] as String?;

      // ZAPISZ TOKEN do localStorage
      if (token != null) {
        html.window.localStorage['jwt_token'] = token;
        print('✅ Token zapisany: ${token.substring(0, 20)}...');
      } else {
        print('❌ Brak tokenu w response!');
      }

      return AuthResult.fromJson(decoded);
    } else {
      throw Exception('Nieprawidłowy email lub hasło');
    }
  }

  // Sprawdź czy użytkownik jest zalogowany
  static bool isLoggedIn() {
    final token = html.window.localStorage['jwt_token'];
    final loggedIn = token != null && token.isNotEmpty;
    print('🔐 isLoggedIn sprawdza token: ${token != null ? "ISTNIEJE" : "BRAK"} → $loggedIn');
    return loggedIn;
  }

  // Wyloguj użytkownika
  static void logout() {
    html.window.localStorage.remove('jwt_token');
    print('🚪 Użytkownik wylogowany, token usunięty');
  }

  // Pobierz zapisany token (do API calls)
  static String? getToken() {
    return html.window.localStorage['jwt_token'];
  }
}
