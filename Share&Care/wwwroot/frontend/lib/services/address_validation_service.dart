import 'dart:convert';

import 'package:http/http.dart' as http;

/// Prosta walidacja pary (kod pocztowy, miasto) z użyciem publicznego API
/// Zippopotam (https://www.zippopotam.us/). Backend może zignorować ten krok,
/// ale pomaga wychwycić oczywiste literówki po stronie klienta.
class AddressValidationService {
  AddressValidationService._();

  /// Zwraca true, jeśli udało się odnaleźć kod w bazie i
  /// przynajmniej jedna z miejscowości pasuje (case-insensitive)
  /// do podanego miasta.
  static Future<bool> validateCityAndPostalCode({
    required String city,
    required String postalCode,
  }) async {
    final trimmedCity = city.trim();
    final trimmedPostal = postalCode.trim();

    if (trimmedCity.isEmpty || trimmedPostal.isEmpty) {
      return false;
    }

    try {
      final uri = Uri.parse('https://api.zippopotam.us/PL/$trimmedPostal');
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        return false;
      }

      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> places = (data['places'] as List<dynamic>? ?? <dynamic>[]);

      final lowerCity = trimmedCity.toLowerCase();
      for (final p in places) {
        if (p is Map<String, dynamic>) {
          final name = (p['place name'] ?? p['place_name'] ?? '').toString();
          if (name.toLowerCase() == lowerCity) {
            return true;
          }
        }
      }
    } catch (_) {
      // W razie problemów z siecią traktujemy walidację jako nieudaną.
      return false;
    }

    return false;
  }
}
