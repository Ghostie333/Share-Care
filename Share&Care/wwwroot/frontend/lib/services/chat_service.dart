import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class ChatThreadSummary {
  final String chatId;
  final String listingId;
  final String listingTitle;
  final String listingStatus; // "Active", "Inactive", "Deleted"
  final String? currentBorrowerId;
  final String otherUserId;
  final String otherUserName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? listingFirstImageId;

  const ChatThreadSummary({
    required this.chatId,
    required this.listingId,
    required this.listingTitle,
    required this.listingStatus,
    this.currentBorrowerId,
    required this.otherUserId,
    required this.otherUserName,
    this.lastMessage,
    this.lastMessageAt,
    this.listingFirstImageId,
  });

  factory ChatThreadSummary.fromJson(Map<String, dynamic> json) {
    return ChatThreadSummary(
      chatId: (json['chatId'] ?? json['ChatId']).toString(),
      listingId: (json['listingId'] ?? json['ListingId']).toString(),
      listingTitle: (json['listingTitle'] ?? json['ListingTitle'] ?? '').toString(),
      listingStatus: (json['listingStatus'] ?? json['ListingStatus'] ?? '').toString(),
        currentBorrowerId:
          (json['currentBorrowerId'] ?? json['CurrentBorrowerId'])?.toString(),
      otherUserId: (json['otherUserId'] ?? json['OtherUserId'] ?? '').toString(),
      otherUserName: (json['otherUserName'] ?? json['OtherUserName'] ?? '').toString(),
      lastMessage: (json['lastMessage'] ?? json['LastMessage'])?.toString(),
      lastMessageAt: (() {
        final raw = (json['lastMessageAt'] ?? json['LastMessageAt'])?.toString();
        if (raw == null || raw.isEmpty) return null;
        return DateTime.tryParse(raw);
      })(),
      listingFirstImageId:
          (json['listingFirstImageId'] ?? json['ListingFirstImageId'])?.toString(),
    );
  }
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final String kind;
  final Map<String, dynamic>? data;
  final DateTime sentAt;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.kind,
    required this.data,
    required this.sentAt,
    required this.isRead,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? dataJson;
    final rawData = json['dataJson'] ?? json['DataJson'];
    if (rawData is String && rawData.isNotEmpty) {
      try {
        dataJson = jsonDecode(rawData) as Map<String, dynamic>;
      } catch (_) {
        dataJson = null;
      }
    }

    return ChatMessage(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      chatId: (json['chatId'] ?? json['ChatId'] ?? '').toString(),
      senderId: (json['senderId'] ?? json['SenderId'] ?? '').toString(),
      content: (json['content'] ?? json['Content'] ?? '').toString(),
      kind: (json['kind'] ?? json['Kind'] ?? 'text').toString(),
      data: dataJson,
      sentAt: DateTime.tryParse(
              (json['sentAt'] ?? json['SentAt'] ?? '').toString()) ??
          DateTime.now(),
      isRead: (json['isRead'] ?? json['IsRead'] ?? false) as bool,
    );
  }
}

/// Serwis odpowiedzialny za komunikację z backendowym modułem czatu.
class ChatService {
  ChatService._();

  /// Pobiera listę czatów zalogowanego użytkownika.
  static Future<List<ChatThreadSummary>> getMyChats() async {
    final http.Response res = await ApiService.get('/chat/my');

    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania czatów: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as List<dynamic>;
    return decoded
        .map((e) => ChatThreadSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Pobiera zarchiwizowane czaty zalogowanego użytkownika.
  static Future<List<ChatThreadSummary>> getArchivedChats() async {
    final http.Response res = await ApiService.get('/chat/history');

    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania historii czatów: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as List<dynamic>;
    return decoded
        .map((e) => ChatThreadSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tworzy (lub zwraca istniejący) czat dla danego ogłoszenia i sprzedającego.
  /// Zwraca identyfikator chatu.
  static Future<String> createChat({
    required String listingId,
    required String sellerId,
  }) async {
    final body = <String, dynamic>{
      'ListingId': listingId,
      'SellerId': sellerId,
    };

    final http.Response res = await ApiService.postJson(
      '/chat',
      body,
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('Błąd tworzenia czatu: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final chatId = (decoded['id'] ?? decoded['Id'])?.toString();
    if (chatId == null || chatId.isEmpty) {
      throw Exception('Brak identyfikatora czatu w odpowiedzi serwera');
    }

    return chatId;
  }

  /// Pobiera historię wiadomości dla wybranego czatu.
  static Future<List<ChatMessage>> getMessages(String chatId) async {
    final http.Response res =
        await ApiService.get('/chat/$chatId/messages');

    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania wiadomości: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as List<dynamic>;
    return decoded
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Wysyła nową wiadomość w ramach danego czatu i zwraca jej reprezentację
  /// zwróconą przez backend.
  static Future<ChatMessage> sendMessage({
    required String chatId,
    required String content,
    String kind = 'text',
    Map<String, dynamic>? data,
  }) async {
    final body = <String, dynamic>{
      'Content': content,
      'Kind': kind,
      'DataJson': data == null ? null : jsonEncode(data),
    };

    final http.Response res = await ApiService.postJson(
      '/chat/$chatId/messages',
      body,
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Błąd wysyłania wiadomości: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ChatMessage.fromJson(decoded);
  }

  /// Archiwizuje ("usuwa") czat dla bieżącego użytkownika.
  static Future<void> archiveChat(String chatId) async {
    final http.Response res = await ApiService.delete('/chat/$chatId');

    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Błąd usuwania czatu: ${res.statusCode}');
    }
  }

  /// Wysyla oferte w ramach chatu zgloszenia.
  static Future<ChatMessage> sendOfferInChat({
    required String chatId,
    required String offerId,
  }) async {
    final body = <String, dynamic>{
      'OfferId': offerId,
    };

    final http.Response res = await ApiService.postJson(
      '/chat/$chatId/offers',
      body,
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Blad wysylania oferty: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ChatMessage.fromJson(decoded);
  }
}
