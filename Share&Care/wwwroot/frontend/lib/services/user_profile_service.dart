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
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      phoneNumber: (json['phoneNumber'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      raiting: (json['raiting'] ?? '').toString(),
      type: (json['type'] ?? '').toString(), 

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

  /// PUT /UserProfile/info/{userId}
  static Future<UserProfileInfo> updateProfile(
    String userId, {
    required String firstName,
    required String lastName,
    required String email,
    required String city,
  }) async {
    final body = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'city': city,
    };

    final http.Response res =
        await ApiService.putJson('/UserProfile/info/$userId', body);

    if (res.statusCode != 200) {
      throw Exception('Błąd zapisu profilu: ${res.statusCode}');
    }

    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    return UserProfileInfo.fromJson(data);
  }
}
