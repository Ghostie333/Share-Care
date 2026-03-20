import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'api_service.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import '../features/models/annoucement.dart';

/// Serwis odpowiedzialny za komunikację z backendem w kontekście ogłoszeń.
///
/// Tu są skoncentrowane endpointy tworzenia, pobierania, aktualizacji
/// i usuwania ogłoszeń.
class AnnouncementService {
  AnnouncementService._();

  /// Pobiera aktywne ogłoszenia użytkownika.
  static Future<List<Announcement>> getUserOffers(String userId) async {
    // Backend udostępnia alias GET /offer/get-user-offers/{userId}
    final http.Response res = await ApiService.get(
      '/offer/get-user-offers/$userId',
    );

    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania ogłoszeń: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    final List<dynamic> items = decoded is Map<String, dynamic>
        ? (decoded['items'] as List<dynamic>? ?? const [])
        : (decoded as List<dynamic>);

    return items
        .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
        .map((a) => a..isOwner = true)
        .toList();
  }

  /// Pobiera aktywne ogłoszenia na stronę główną.
  static Future<List<Announcement>> getActiveOffers({
    String? currentUserId,
  }) async {
    final http.Response res = await ApiService.get('/offer/get-offers');

    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania ogłoszeń: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    final List<dynamic> items = decoded is Map<String, dynamic>
        ? (decoded['items'] as List<dynamic>? ?? const [])
        : (decoded as List<dynamic>);

    final offers = items
        .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
        .toList();

    if (currentUserId != null && currentUserId.isNotEmpty) {
      for (final a in offers) {
        a.isOwner = a.userId == currentUserId;
      }
    }

    return offers;
  }

  /// Tworzy nową ofertę (Offer) w backendzie.
  ///
  /// Backend: POST /offer/create-offer (multipart/form-data).
  static Future<Announcement> createOffer(
    Announcement announcement, {
    List<XFile>? images,
  }) async {
    final token = await AuthService.getToken();

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/offer/create-offer');
    final request = http.MultipartRequest('POST', uri);

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields.addAll({
      'Title': announcement.title,
      'ContactName': announcement.contactName ?? announcement.ownerName,
      'Category': announcement.category ?? 'Inne',
      'ContactNumber': announcement.contactNumber ?? '',
      'Description': announcement.description,
      // Lat/Lng są opcjonalne po stronie backendu (i walidowane dopiero gdy
      // jeden z nich jest podany).
      // Na razie nie próbujemy mapować tekstowej lokalizacji na współrzędne.
    });

    if (images != null && images.isNotEmpty) {
      for (final image in images) {
        if (image.path.isEmpty) continue;
        request.files.add(
          await http.MultipartFile.fromPath(
            'Images',
            image.path,
            filename: image.name,
          ),
        );
      }
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Błąd tworzenia ogłoszenia: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;

    final offerId = decoded['offerId'] ?? decoded['offer_id'];
    final imageIds = decoded['imageIds'] as List<dynamic>? ?? const [];

    return Announcement(
      id: offerId?.toString() ?? announcement.id,
      userId: announcement.userId,
      title: announcement.title,
      description: announcement.description,
      location: announcement.location,
      deposit: announcement.deposit,
      ownerName: announcement.ownerName,
      isActive: true,
      createdAt: DateTime.now(),
      imageUrls: imageIds.map((e) => e.toString()).toList(),
      isOwner: true,
      category: announcement.category,
      contactName: announcement.contactName,
      contactNumber: announcement.contactNumber,
    );
  }

  /// Aktualizuje istniejącą ofertę (Offer) – WYMAGA odpowiedniego endpointu
  /// po stronie .NET (np. PUT /offer/{offerId}).
  static Future<Announcement> updateOffer(Announcement announcement) async {
    final Map<String, dynamic> body = announcement.toJson();

    final http.Response res =
        await ApiService.putJson('/offer/${announcement.id}', body);

    if (res.statusCode != 200) {
      throw Exception('Błąd aktualizacji ogłoszenia: ${res.statusCode}');
    }

    final Map<String, dynamic> decoded =
        jsonDecode(res.body) as Map<String, dynamic>;
    return Announcement.fromJson(decoded);
  }

  /// Usuwa ofertę (Offer) po OfferId – WYMAGA odpowiedniego endpointu
  /// po stronie .NET (np. DELETE /offer/{offerId}).
  static Future<void> deleteOffer(String id) async {
    final http.Response res = await ApiService.delete('/offer/$id');

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Błąd usuwania ogłoszenia: ${res.statusCode}');
    }
  }
}