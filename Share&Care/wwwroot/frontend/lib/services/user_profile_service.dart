import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

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
}
