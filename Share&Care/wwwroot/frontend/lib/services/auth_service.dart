import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

enum SocialAuthProvider { google, outlook, apple }

extension _SocialAuthProviderApiValue on SocialAuthProvider {
  String get apiValue {
    switch (this) {
      case SocialAuthProvider.google:
        return 'Google';
      case SocialAuthProvider.outlook:
        return 'Outlook';
      case SocialAuthProvider.apple:
        return 'Apple';
    }
  }
}

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
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static DateTime? _tryReadTokenExpiry(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> json = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = json['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      }
      if (exp is String) {
        final parsed = int.tryParse(exp);
        if (parsed != null) {
          return DateTime.fromMillisecondsSinceEpoch(parsed * 1000, isUtc: true);
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static bool _isTokenExpired(String token) {
    final expiry = _tryReadTokenExpiry(token);
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now().toUtc().add(const Duration(minutes: 1)));
  }

  static Future<void> _writeStorage(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }
    await _secureStorage.write(key: key, value: value);
  }

  static Future<String?> _readStorage(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    return _secureStorage.read(key: key);
  }

  static Future<void> _deleteStorage(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }
    await _secureStorage.delete(key: key);
  }

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
    String? street,
    String? buildingNumber,
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
      'Street': street,
      'BuildingNumber': buildingNumber,
    };

    final http.Response res = await ApiService.postJson(
      '/UserRegistration/user-registry',
      body,
      includeAuth: false,
    );

    debugPrint('[registerUser] status: ${res.statusCode}');
    debugPrint('[registerUser] body: ${res.body}');

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final token = decoded['access_token'] as String?;

      if (token != null && token.isNotEmpty) {
        await _writeStorage('jwt_token', token);
        debugPrint('Token saved after registration: ${token.substring(0, 20)}...');
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
    final body = <String, dynamic>{'Email': email, 'Password': password};

    debugPrint('[login] body: $body');

    final http.Response res = await ApiService.postJson(
      '/UserLogin/login',
      body,
      includeAuth: false,
    );

    debugPrint('[login] status: ${res.statusCode}');
    debugPrint('[login] body: ${res.body}');

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final result = AuthResult.fromJson(decoded);

      await _persistAuthResult(result);
      return result;
    } else {
      throw Exception('Nieprawidłowy email lub hasło');
    }
  }

  /// Logowanie społecznościowe przez backend API.
  ///
  /// Frontend wysyła wybranego providera, a backend realizuje docelowy flow.
  static Future<AuthResult> loginWithSocial({
    required SocialAuthProvider provider,
    String? idToken,
  }) async {
    final body = <String, dynamic>{
      'Provider': provider.apiValue,
      if (idToken != null && idToken.isNotEmpty) 'IdToken': idToken,
    };

    final http.Response res = await ApiService.postJson(
      '/UserLogin/social-login',
      body,
      includeAuth: false,
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      if (res.statusCode == 404) {
        throw Exception('Endpoint logowania ${provider.apiValue} jest niedostępny.');
      }
      throw Exception('Błąd logowania ${provider.apiValue}: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final result = _parseAuthResultPayload(decoded);
    await _persistAuthResult(result);
    return result;
  }

  /// Rejestracja społecznościowa przez backend API.
  ///
  /// Frontend wysyła wybranego providera, a backend realizuje docelowy flow.
  static Future<AuthResult> registerWithSocial({
    required SocialAuthProvider provider,
    String? idToken,
  }) async {
    final body = <String, dynamic>{
      'Provider': provider.apiValue,
      if (idToken != null && idToken.isNotEmpty) 'IdToken': idToken,
    };

    final http.Response res = await ApiService.postJson(
      '/UserRegistration/social-register',
      body,
      includeAuth: false,
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      if (res.statusCode == 404) {
        throw Exception('Endpoint rejestracji ${provider.apiValue} jest niedostępny.');
      }
      throw Exception('Błąd rejestracji ${provider.apiValue}: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final result = _parseAuthResultPayload(decoded);
    await _persistAuthResult(result);
    return result;
  }

  static AuthResult _parseAuthResultPayload(Map<String, dynamic> decoded) {
    final userRaw = decoded['user'];
    if (userRaw is Map<String, dynamic>) {
      final merged = <String, dynamic>{
        ...userRaw,
        'access_token': decoded['access_token'] ?? decoded['accessToken'] ?? decoded['token'],
      };
      return AuthResult.fromJson(merged);
    }

    return AuthResult.fromJson(decoded);
  }

  static Future<void> _persistAuthResult(AuthResult result) async {
    final token = result.accessToken;
    if (token != null && token.isNotEmpty) {
      await _writeStorage('jwt_token', token);
    }

    await _writeStorage('auth_result', jsonEncode(result.toJson()));
  }

  // Sprawdź czy użytkownik jest zalogowany
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Wyloguj użytkownika
  static Future<void> logout() async {
    await _deleteStorage('jwt_token');
    await _deleteStorage('auth_result');
  }

  // Pobierz zapisany token (do API calls)
  static Future<String?> getToken() async {
    final token = await _readStorage('jwt_token');
    if (token == null || token.isEmpty) return null;
    if (_isTokenExpired(token)) {
      await logout();
      return null;
    }
    return token;
  }

  // Pobierz zapamiętane dane zalogowanego użytkownika (o ile istnieją).
  static Future<AuthResult?> getStoredAuthResult() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;

    final raw = await _readStorage('auth_result');
    if (raw == null || raw.isEmpty) return null;
    try {
      final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
      return AuthResult.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
