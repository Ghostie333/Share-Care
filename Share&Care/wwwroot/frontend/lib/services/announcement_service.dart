import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import '../features/models/annoucement.dart';

/// Serwis odpowiedzialny za komunikację z backendem w kontekście ogłoszeń.
///
/// Tu są skoncentrowane endpointy tworzenia, pobierania, aktualizacji
/// i usuwania ogłoszeń.
class AnnouncementService {
  AnnouncementService._();

  /// Pobiera wszystkie oferty (GET /offer/get-offers), a następnie filtruje
  /// je po UserId. Dzięki temu nie potrzebujemy osobnego endpointu per użytkownik.
  static Future<List<Announcement>> getUserOffers(String userId) async {
    final http.Response res = await ApiService.get('/offer/get-offers');

    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania ogłoszeń: ${res.statusCode}');
    }

    final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
    final all = data
        .map(
          (e) => Announcement.fromJson(e as Map<String, dynamic>),
        )
        .toList();

    // Zwracamy tylko oferty bieżącego użytkownika.
    return all.where((a) => a.userId == userId).toList();
  }

  /// Tworzy nową ofertę (Offer) w backendzie.
  ///
  /// Aktualny backend: POST /offer/create-offer (multipart/form-data).
  ///
  /// Poniżej wysyłamy JSON; aby to zadziałało 1:1, backend należałoby
  /// dostosować (np. dodać wersję przyjmującą application/json).
  static Future<Announcement> createOffer(Announcement announcement) async {
    final Map<String, dynamic> body = announcement.toJson();

    final http.Response res =
        await ApiService.postJson('/offer/create-offer', body);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Błąd tworzenia ogłoszenia: ${res.statusCode}');
    }

    final Map<String, dynamic> decoded =
        jsonDecode(res.body) as Map<String, dynamic>;
    return Announcement.fromJson(decoded);
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