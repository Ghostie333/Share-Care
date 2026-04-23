import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_service.dart';
import 'auth_service.dart';

class UserProfileInfo {
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber; 
  final String city;
  final String raiting; 
  final String type;

  const UserProfileInfo({
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.email,
    required this.city,
    required this.raiting, 
    required this.type,
  });

  factory UserProfileInfo.fromJson(Map<String, dynamic> json) {
    return UserProfileInfo(
      firstName:
          (json['firstName'] ?? json['FirstName'] ?? json['name'] ?? '').toString(),
      lastName: (json['lastName'] ?? json['LastName'] ?? json['surname'] ?? '').toString(),
      phoneNumber:
          (json['phoneNumber'] ?? json['PhoneNumber'] ?? json['phone'] ?? '').toString(),
      email: (json['email'] ?? json['Email'] ?? '').toString(),
      city: (json['city'] ?? json['City'] ?? '').toString(),
      raiting: (json['raiting'] ?? json['Raiting'] ?? '').toString(),
      type: (json['type'] ?? json['Type'] ?? '').toString(),

    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber, 
      'email': email,
      'city': city,
      'raiting': raiting, 
      'type': type, 
    };
  }
}

class UserProfileService {
  UserProfileService._();

  /// GET /UserProfile/info/{userId}
  static Future<UserProfileInfo> fetchProfile(String userId) async {
    final http.Response res = await ApiService.get('/UserProfile/info/$userId');

    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania profilu: ${res.statusCode}');
    }

    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    return UserProfileInfo.fromJson(data);
  }

  /// PUT /UserProfile/update-profile
  /// Aktualizuje profil aktualnie zalogowanego użytkownika (na podstawie JWT).
  static Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    String? birthday,
    String? phoneNumber,
    String? city,
    String? postalCode,
  }) async {
    final body = <String, dynamic>{
      'FirstName': firstName,
      'LastName': lastName,
      'Email': email,
      'Birthday': birthday,
      'PhoneNumber': phoneNumber,
      'City': city,
      'PostalCode': postalCode,
    };

    final http.Response res =
        await ApiService.putJson('/UserProfile/update-profile', body);

    if (res.statusCode != 200) {
      throw Exception('Błąd zapisu profilu: ${res.statusCode} ${res.body}');
    }
  }

  /// DELETE /UserProfile/delete-profile
  /// Usuwa profil aktualnie zalogowanego użytkownika.
  static Future<void> deleteProfile() async {
    final http.Response res =
        await ApiService.delete('/UserProfile/delete-profile');

    if (res.statusCode != 200) {
      throw Exception('Błąd usuwania profilu: ${res.statusCode} ${res.body}');
    }
  }

  /// POST /UserProfile/change-password
  /// Zmienia hasło zalogowanego użytkownika.
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final body = <String, dynamic>{
      'CurrentPassword': currentPassword,
      'NewPassword': newPassword,
    };

    final http.Response res =
        await ApiService.postJson('/UserProfile/change-password', body);

    if (res.statusCode != 200) {
      throw Exception('Błąd zmiany hasła: ${res.statusCode} ${res.body}');
    }
  }

  /// POST /UserProfile/photo
  /// Wysyła nowe zdjęcie profilowe użytkownika do backendu.
  static Future<void> uploadAvatar(File imageFile) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/UserProfile/photo');
    final request = http.MultipartRequest('POST', uri);

    final token = await AuthService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ),
    );

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      throw Exception('Błąd zapisu zdjęcia profilowego: ${res.statusCode} ${res.body}');
    }
  }
}
