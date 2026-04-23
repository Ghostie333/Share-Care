import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
      userId: (json['userId'] ??
              json['user_id'] ??
              json['UserId'] ??
              json['UserID'] ??
              json['User_ID'])
          ?.toString(),
      email: (json['email'] ?? json['Email'] ?? json['userEmail'])?.toString() ??
          '',
      firstName: (json['firstName'] ??
              json['FirstName'] ??
              json['name'] ??
              json['Name'])
          ?.toString() ??
          '',
      lastName: (json['lastName'] ??
              json['LastName'] ??
              json['surname'] ??
              json['Surname'])
          ?.toString() ??
          '',
      accessToken: (json['access_token'] ??
              json['accessToken'] ??
              json['token'] ??
              json['Token'])
          ?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'accessToken': accessToken,
    };
  }
}

class AuthService {
  // jeden współdzielony storage dla całej aplikacji
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

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

    debugPrint('[registerUser] status: ${res.statusCode}');
    debugPrint('[registerUser] body: ${res.body}');


    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final token = decoded['access_token'] as String?;

      // ZAPISZ TOKEN do secure storage
      if (token != null) {
        await _secureStorage.write(key: 'jwt_token', value: token);
        print('Token zapisany po rejestracji: ${token.substring(0, 20)}...');
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

    debugPrint('[login] body: $body');

    final http.Response res =
        await ApiService.postJson('/UserLogin/login', body, includeAuth: false);

     debugPrint('[login] status: ${res.statusCode}');
    debugPrint('[login] body: ${res.body}');


    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final token = decoded['access_token'] as String?;

      // ZAPISZ TOKEN do secure storage
      if (token != null) {
        await _secureStorage.write(key: 'jwt_token', value: token);
        print('Token zapisany po logowaniu: ${token.substring(0, 20)}...');
      } else {
        print('Brak tokenu w response!');
      }
      final result = AuthResult.fromJson(decoded);

      // Zapisz również podstawowe dane użytkownika, aby móc odtworzyć je przy starcie aplikacji.
      await _secureStorage.write(
        key: 'auth_result',
        value: jsonEncode(result.toJson()),
      );

      return result;
    } else {
      throw Exception('Nieprawidłowy email lub hasło');
    }
  }

  // Sprawdź czy użytkownik jest zalogowany
  static Future<bool> isLoggedIn() async {
    final token = await _secureStorage.read(key: 'jwt_token');
    final loggedIn = token != null && token.isNotEmpty;
    print('isLoggedIn sprawdza token: ${token != null ? "ISTNIEJE" : "BRAK"} → $loggedIn');
    return loggedIn;
  }

  // Wyloguj użytkownika
  static Future<void> logout() async {
    await _secureStorage.delete(key: 'jwt_token');
      await _secureStorage.delete(key: 'auth_result');
    print('Użytkownik wylogowany, token usunięty');
  }

  // Pobierz zapisany token (do API calls)
  static Future<String?> getToken() async {
    final token = await _secureStorage.read(key: 'jwt_token');
    return token;
  }

   // Pobierz zapamiętane dane zalogowanego użytkownika (o ile istnieją).
  static Future<AuthResult?> getStoredAuthResult() async {
    final raw = await _secureStorage.read(key: 'auth_result');
    if (raw == null || raw.isEmpty) return null;
    try {
      final Map<String, dynamic> data =
          jsonDecode(raw) as Map<String, dynamic>;
      return AuthResult.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}