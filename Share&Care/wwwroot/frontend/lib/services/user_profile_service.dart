import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../features/models/annoucement.dart';

class UserProfileInfo {
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String? brithday;
  final String city;
  final String postalCode;
  final String street;
  final String buildingNumber;
  final String raiting;
  final int ratingCount;
  final int credits;
  final double walletBalance;
  final double walletLocked;
  final String type;
  final bool showFirstName;
  final bool showLastName;
  final bool showCity;
  final bool showPhoneNumber;
  final bool showProfileImage;
  final int offersCount;
  final int activeOffersCount;
  final int completedCount;
  final int negotiationsCount;
  final int giveOffersCount;
  final int firstDayPurchasesCount;
  final int differentCitiesCount;
  final int loweredPriceChangesCount;

  const UserProfileInfo({
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.email,
    required this.city,
    required this.postalCode,
    required this.street,
    required this.buildingNumber,
    required this.brithday,
    required this.raiting,
    required this.ratingCount,
    required this.credits,
    required this.walletBalance,
    required this.walletLocked,
    required this.type,
    required this.showFirstName,
    required this.showLastName,
    required this.showCity,
    required this.showPhoneNumber,
    required this.showProfileImage,
    required this.offersCount,
    required this.activeOffersCount,
    required this.completedCount,
    required this.negotiationsCount,
    required this.giveOffersCount,
    required this.firstDayPurchasesCount,
    required this.differentCitiesCount,
    required this.loweredPriceChangesCount,
  });

  factory UserProfileInfo.fromJson(Map<String, dynamic> json) {
    return UserProfileInfo(
      firstName: (json['firstName'] ?? json['FirstName'] ?? json['name'] ?? '')
          .toString(),
      lastName: (json['lastName'] ?? json['LastName'] ?? json['surname'] ?? '')
          .toString(),
      phoneNumber:
          (json['phoneNumber'] ?? json['PhoneNumber'] ?? json['phone'] ?? '')
              .toString(),
        brithday: (json['brithday'] ?? json['Brithday'] ?? json['birthday'])
          ?.toString(),
      email: (json['email'] ?? json['Email'] ?? '').toString(),
      city: (json['city'] ?? json['City'] ?? '').toString(),
      postalCode: (json['postalCode'] ?? json['PostalCode'] ?? '').toString(),
      street: (json['street'] ?? json['Street'] ?? '').toString(),
      buildingNumber:
          (json['buildingNumber'] ?? json['BuildingNumber'] ?? '').toString(),
      raiting: (json['raiting'] ?? json['Raiting'] ?? '').toString(),
        ratingCount: int.tryParse((json['ratingCount'] ?? 0).toString()) ?? 0,
        credits: int.tryParse((json['credits'] ?? 0).toString()) ?? 0,
        walletBalance:
          double.tryParse((json['walletBalance'] ?? 0).toString()) ?? 0,
        walletLocked:
          double.tryParse((json['walletLocked'] ?? 0).toString()) ?? 0,
      type: (json['type'] ?? json['Type'] ?? '').toString(),
          showFirstName:
            (json['showFirstName'] ?? json['ShowFirstName'] ?? true) as bool,
          showLastName:
            (json['showLastName'] ?? json['ShowLastName'] ?? true) as bool,
          showCity: (json['showCity'] ?? json['ShowCity'] ?? true) as bool,
          showPhoneNumber:
            (json['showPhoneNumber'] ?? json['ShowPhoneNumber'] ?? false) as bool,
          showProfileImage:
            (json['showProfileImage'] ?? json['ShowProfileImage'] ?? true) as bool,
          offersCount: int.tryParse((json['offersCount'] ?? 0).toString()) ?? 0,
          activeOffersCount:
            int.tryParse((json['activeOffersCount'] ?? 0).toString()) ?? 0,
          completedCount: int.tryParse((json['completedCount'] ?? 0).toString()) ?? 0,
          negotiationsCount:
            int.tryParse((json['negotiationsCount'] ?? 0).toString()) ?? 0,
          giveOffersCount:
            int.tryParse((json['giveOffersCount'] ?? 0).toString()) ?? 0,
          firstDayPurchasesCount:
            int.tryParse((json['firstDayPurchasesCount'] ?? 0).toString()) ?? 0,
          differentCitiesCount:
            int.tryParse((json['differentCitiesCount'] ?? 0).toString()) ?? 0,
          loweredPriceChangesCount:
            int.tryParse((json['loweredPriceChangesCount'] ?? 0).toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'brithday': brithday,
      'email': email,
      'city': city,
      'postalCode': postalCode,
      'street': street,
      'buildingNumber': buildingNumber,
      'raiting': raiting,
      'ratingCount': ratingCount,
      'credits': credits,
      'walletBalance': walletBalance,
      'walletLocked': walletLocked,
      'type': type,
      'showFirstName': showFirstName,
      'showLastName': showLastName,
      'showCity': showCity,
      'showPhoneNumber': showPhoneNumber,
      'showProfileImage': showProfileImage,
      'offersCount': offersCount,
      'activeOffersCount': activeOffersCount,
      'completedCount': completedCount,
      'negotiationsCount': negotiationsCount,
      'giveOffersCount': giveOffersCount,
      'firstDayPurchasesCount': firstDayPurchasesCount,
      'differentCitiesCount': differentCitiesCount,
      'loweredPriceChangesCount': loweredPriceChangesCount,
    };
  }
}

class PublicProfileInfo {
  final String userId;
  final String firstName;
  final String lastName;
  final String city;
  final String phoneNumber;
  final bool showFirstName;
  final bool showLastName;
  final bool showCity;
  final bool showPhoneNumber;
  final bool showProfileImage;
  final double raiting;
  final int ratingCount;
  final int offersCount;
  final int activeOffersCount;
  final int activeReportsCount;
  final int completedCount;
  final int negotiationsCount;
  final int giveOffersCount;
  final int firstDayPurchasesCount;
  final int differentCitiesCount;
  final int loweredPriceChangesCount;
  final String rank;
  final List<Announcement> activeOffers;
  final List<Announcement> activeReports;

  const PublicProfileInfo({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.city,
    required this.phoneNumber,
    required this.showFirstName,
    required this.showLastName,
    required this.showCity,
    required this.showPhoneNumber,
    required this.showProfileImage,
    required this.raiting,
    required this.ratingCount,
    required this.offersCount,
    required this.activeOffersCount,
    required this.activeReportsCount,
    required this.completedCount,
    required this.negotiationsCount,
    required this.giveOffersCount,
    required this.firstDayPurchasesCount,
    required this.differentCitiesCount,
    required this.loweredPriceChangesCount,
    required this.rank,
    required this.activeOffers,
    required this.activeReports,
  });

  factory PublicProfileInfo.fromJson(Map<String, dynamic> json) {
    final offersJson =
      (json['activeOffers'] as List<dynamic>? ?? json['offers'] as List<dynamic>? ?? const []);
    final reportsJson =
      (json['activeReports'] as List<dynamic>? ?? const []);
    return PublicProfileInfo(
      userId: (json['userId'] ?? '').toString(),
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      phoneNumber: (json['phoneNumber'] ?? '').toString(),
      showFirstName:
        (json['showFirstName'] ?? json['ShowFirstName'] ?? true) as bool,
      showLastName:
        (json['showLastName'] ?? json['ShowLastName'] ?? true) as bool,
      showCity: (json['showCity'] ?? json['ShowCity'] ?? true) as bool,
      showPhoneNumber:
        (json['showPhoneNumber'] ?? json['ShowPhoneNumber'] ?? false) as bool,
      showProfileImage:
        (json['showProfileImage'] ?? json['ShowProfileImage'] ?? true) as bool,
      raiting: double.tryParse((json['raiting'] ?? 0).toString()) ?? 0,
      ratingCount: int.tryParse((json['ratingCount'] ?? 0).toString()) ?? 0,
      offersCount: int.tryParse((json['offersCount'] ?? 0).toString()) ?? 0,
      activeOffersCount:
        int.tryParse((json['activeOffersCount'] ?? 0).toString()) ?? 0,
      activeReportsCount:
        int.tryParse((json['activeReportsCount'] ?? 0).toString()) ?? 0,
      completedCount: int.tryParse((json['completedCount'] ?? 0).toString()) ?? 0,
      negotiationsCount:
        int.tryParse((json['negotiationsCount'] ?? 0).toString()) ?? 0,
      giveOffersCount:
        int.tryParse((json['giveOffersCount'] ?? 0).toString()) ?? 0,
      firstDayPurchasesCount:
        int.tryParse((json['firstDayPurchasesCount'] ?? 0).toString()) ?? 0,
      differentCitiesCount:
        int.tryParse((json['differentCitiesCount'] ?? 0).toString()) ?? 0,
      loweredPriceChangesCount:
        int.tryParse((json['loweredPriceChangesCount'] ?? 0).toString()) ?? 0,
      rank: (json['rank'] ?? '').toString(),
      activeOffers: offersJson
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList(),
      activeReports: reportsJson
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
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

  /// GET /UserProfile/public/{userId}
  static Future<PublicProfileInfo> fetchPublicProfile(String userId) async {
    final http.Response res = await ApiService.get(
      '/UserProfile/public/$userId',
      includeAuth: false,
    );

    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania profilu: ${res.statusCode}');
    }

    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    return PublicProfileInfo.fromJson(data);
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
    String? street,
    String? buildingNumber,
    bool? showFirstName,
    bool? showLastName,
    bool? showCity,
    bool? showPhoneNumber,
    bool? showProfileImage,
  }) async {
    final body = <String, dynamic>{
      'FirstName': firstName,
      'LastName': lastName,
      'Email': email,
      'Birthday': birthday,
      'PhoneNumber': phoneNumber,
      'City': city,
      'PostalCode': postalCode,
      'Street': street,
      'BuildingNumber': buildingNumber,
      if (showFirstName != null) 'ShowFirstName': showFirstName,
      if (showLastName != null) 'ShowLastName': showLastName,
      if (showCity != null) 'ShowCity': showCity,
      if (showPhoneNumber != null) 'ShowPhoneNumber': showPhoneNumber,
      if (showProfileImage != null) 'ShowProfileImage': showProfileImage,
    };

    final http.Response res = await ApiService.putJson(
      '/UserProfile/update-profile',
      body,
    );

    if (res.statusCode != 200) {
      throw Exception('Błąd zapisu profilu: ${res.statusCode} ${res.body}');
    }
  }

  /// DELETE /UserProfile/delete-profile
  /// Usuwa profil aktualnie zalogowanego użytkownika.
  static Future<void> deleteProfile() async {
    final http.Response res = await ApiService.delete(
      '/UserProfile/delete-profile',
    );

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

    final http.Response res = await ApiService.postJson(
      '/UserProfile/change-password',
      body,
    );

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
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      throw Exception(
        'Błąd zapisu zdjęcia profilowego: ${res.statusCode} ${res.body}',
      );
    }
  }

  /// POST /UserProfile/rate/{userId}
  static Future<void> submitRating({
    required String userId,
    required int score,
  }) async {
    final body = <String, dynamic>{
      'Score': score,
    };

    final http.Response res = await ApiService.postJson(
      '/UserProfile/rate/$userId',
      body,
    );

    if (res.statusCode != 200) {
      throw Exception('Błąd zapisu oceny: ${res.statusCode} ${res.body}');
    }
  }
}
