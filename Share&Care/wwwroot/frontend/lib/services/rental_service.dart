import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'api_service.dart';

class RentalService {
  RentalService._();

  static Future<void> startRental({
    required String offerId,
    DateTime? deadlineAt,
  }) async {
    final body = <String, dynamic>{
      'OfferId': offerId,
      if (deadlineAt != null) 'DeadlineAt': deadlineAt.toUtc().toIso8601String(),
    };

    final http.Response res = await ApiService.postJson('/rental/start', body);
    if (res.statusCode != 200) {
      throw Exception('Błąd startu wypożyczenia: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> approveRental(String offerId) async {
    final http.Response res = await ApiService.postJson('/rental/approve/$offerId', {});
    if (res.statusCode != 200) {
      throw Exception('Błąd akceptacji: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> declineRental(String offerId) async {
    final http.Response res = await ApiService.postJson('/rental/decline/$offerId', {});
    if (res.statusCode != 200) {
      throw Exception('Błąd odrzucenia: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> takerReturn({
    required String offerId,
    required List<XFile> images,
  }) async {
    final uri = Uri.parse('${ApiService.apiBaseUrl}/rental/taker-return/$offerId');
    final request = http.MultipartRequest('POST', uri);

    final headers = await ApiService.buildHeaders(includeAuth: true);
    request.headers.addAll(headers);

    for (final image in images) {
      request.files.add(
        await http.MultipartFile.fromPath('images', image.path, filename: image.name),
      );
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw Exception('Błąd zgłoszenia zwrotu: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> giverReview({
    required String offerId,
    required String condition,
    required List<XFile> images,
  }) async {
    final uri = Uri.parse('${ApiService.apiBaseUrl}/rental/giver-review/$offerId');
    final request = http.MultipartRequest('POST', uri);

    final headers = await ApiService.buildHeaders(includeAuth: true);
    request.headers.addAll(headers);

    request.fields['Condition'] = condition;

    for (final image in images) {
      request.files.add(
        await http.MultipartFile.fromPath('images', image.path, filename: image.name),
      );
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw Exception('Błąd oceny zwrotu: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> claimEscrow(String offerId) async {
    final http.Response res = await ApiService.postJson('/rental/claim/$offerId', {});
    if (res.statusCode != 200) {
      throw Exception('Błąd przejęcia kaucji: ${res.statusCode} ${res.body}');
    }
  }
}
