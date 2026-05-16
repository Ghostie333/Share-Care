import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
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

  static ({double lat, double lng})? _tryParseLatLng(String raw) {
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90) return null;
    if (lng < -180 || lng > 180) return null;
    return (lat: lat, lng: lng);
  }

  static Future<({double lat, double lng})?> _geocodeWithMapTiler(
    String query,
  ) async {
    final key = AppConfig.mapTilerApiKey;
    if (key.isEmpty) return null;

    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final encoded = Uri.encodeComponent(trimmed);
    final uri = Uri.parse(
      'https://api.maptiler.com/geocoding/$encoded.json?key=$key&limit=1',
    );

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = (data['features'] as List<dynamic>? ?? const []);
      if (features.isEmpty) return null;

      final first = features.first as Map<String, dynamic>;
      final geometry = first['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'];

      // MapTiler geocoding: [lng, lat]
      if (coords is List && coords.length >= 2) {
        final lng = coords[0];
        final lat = coords[1];
        if (lat is num && lng is num) {
          return (lat: lat.toDouble(), lng: lng.toDouble());
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

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

  /// Pobiera pojedynczą ofertę po identyfikatorze.
  static Future<Announcement> getOfferById(
    String offerId, {
    String? currentUserId,
  }) async {
    final http.Response res = await ApiService.get('/offer/get-offer/$offerId');

    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania oferty: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final ad = Announcement.fromJson(decoded);
    if (currentUserId != null && currentUserId.isNotEmpty) {
      ad.isOwner = ad.userId == currentUserId;
    }
    return ad;
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
        .where((a) => a.isActive)
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
      'OfferKind': announcement.offerKind,
      'ContactNumber': announcement.contactNumber ?? '',
      'Description': announcement.description,
      'LocationText': announcement.location,
    });

    final deposit = announcement.deposit;
    if (deposit != null) {
      request.fields['Deposit'] = deposit.toString();
    }

    final loc = announcement.location.trim();
    ({double lat, double lng})? coords;
    if (loc.isNotEmpty) {
      coords = _tryParseLatLng(loc) ?? await _geocodeWithMapTiler(loc);
      if (coords != null) {
        request.fields['Lat'] = coords.lat.toString();
        request.fields['Lng'] = coords.lng.toString();
      }
    }

    if (images != null && images.isNotEmpty) {
      for (final image in images) {
        // Flutter Web: nie ma prawdziwej ścieżki pliku -> wysyłamy bajty.
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          if (bytes.isEmpty) continue;

          request.files.add(
            http.MultipartFile.fromBytes(
              'Images',
              bytes,
              filename: image.name,
            ),
          );
        } else {
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
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Błąd tworzenia ogłoszenia: ${res.statusCode} ${res.body}');
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
      offerKind: announcement.offerKind,
      category: announcement.category,
      contactName: announcement.contactName,
      contactNumber: announcement.contactNumber,
      lat: coords?.lat,
      lng: coords?.lng,
    );
  }

  /// Aktualizuje istniejącą ofertę (Offer) – WYMAGA odpowiedniego endpointu
  /// po stronie .NET (np. PUT /offer/{offerId}).
  static Future<Announcement> updateOffer(Announcement announcement) async {
    final Map<String, dynamic> body = announcement.toJson();

    final http.Response res = await ApiService.putJson(
      '/offer/update-offer/${announcement.id}',
      body,
    );

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
    final http.Response res = await ApiService.delete(
      '/offer/remove-offer/$id',
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Błąd usuwania ogłoszenia: ${res.statusCode}');
    }
  }

  /// Oznacza ofertę jako nieaktywną (Status = "Inactive") po stronie backendu.
  ///
  /// Backend: POST /offer/close-offer/{offerId}
  static Future<void> closeOffer(String id) async {
    final http.Response res = await ApiService.postJson(
      '/offer/close-offer/$id',
      <String, dynamic>{},
    );

    if (res.statusCode != 200) {
      throw Exception('Błąd zamykania ogłoszenia: ${res.statusCode}');
    }
  }
}
