import 'package:http/http.dart' as http;

import 'api_service.dart';

class TicketService {
  TicketService._();

  static Future<void> createTicket({
    required String reason,
    required String description,
    String? listingId,
    String? chatId,
    String? targetUserId,
  }) async {
    final body = <String, dynamic>{
      'Reason': reason,
      'Description': description,
      if (listingId != null && listingId.isNotEmpty) 'ListingId': listingId,
      if (chatId != null && chatId.isNotEmpty) 'ChatId': chatId,
      if (targetUserId != null && targetUserId.isNotEmpty)
        'TargetUserId': targetUserId,
    };

    final http.Response res = await ApiService.postJson('/tickets', body);
    if (res.statusCode != 200) {
      throw Exception(
        'Blad wysylania zgloszenia: ${res.statusCode} ${res.body}',
      );
    }
  }
}
