import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

import 'api_service.dart';

class EscrowDto {
  final String? id;
  final String? offerId;
  final String? borrowerId;
  final String? lenderId;
  final double amount;
  final String? status;
  final DateTime? deadlineAt;
  final DateTime? inspectionDeadlineAt;
  final String? returnStatus;
  final String? condition;

  const EscrowDto({
    this.id,
    this.offerId,
    this.borrowerId,
    this.lenderId,
    required this.amount,
    this.status,
    this.deadlineAt,
    this.inspectionDeadlineAt,
    this.returnStatus,
    this.condition,
  });

  static DateTime? _parseDate(dynamic v) {
    final raw = v?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  factory EscrowDto.fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount'] ?? json['Amount'];
    final amount = double.tryParse((amountRaw ?? 0).toString()) ?? 0;
    return EscrowDto(
      id: (json['id'] ?? json['Id'])?.toString(),
      offerId: (json['offerId'] ?? json['OfferId'])?.toString(),
      borrowerId: (json['borrowerId'] ?? json['BorrowerId'])?.toString(),
      lenderId: (json['lenderId'] ?? json['LenderId'])?.toString(),
      amount: amount,
      status: (json['status'] ?? json['Status'])?.toString(),
      deadlineAt: _parseDate(json['deadlineAt'] ?? json['DeadlineAt']),
      inspectionDeadlineAt:
          _parseDate(json['inspectionDeadlineAt'] ?? json['InspectionDeadlineAt']),
      returnStatus: (json['returnStatus'] ?? json['ReturnStatus'])?.toString(),
      condition: (json['condition'] ?? json['Condition'])?.toString(),
    );
  }
}

class RentalService {
  RentalService._();

  static Future<EscrowDto> getEscrow(String offerId) async {
    final http.Response res = await ApiService.get('/rental/escrow/$offerId');
    if (res.statusCode != 200) {
      throw Exception('Błąd pobrania escrow: ${res.statusCode} ${res.body}');
    }

    final Map<String, dynamic> decoded =
        jsonDecode(res.body) as Map<String, dynamic>;
    return EscrowDto.fromJson(decoded);
  }

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
    // ApiService.buildHeaders() ustawia Content-Type na application/json,
    // co psuje multipart/form-data (brak boundary). Dla MultipartRequest
    // zostawiamy tylko Authorization i inne bezpieczne nagłówki.
    headers.remove('Content-Type');
    request.headers.addAll(headers);

    for (final image in images) {
      // Flutter Web: MultipartFile.fromPath wymaga dart:io, więc wysyłamy bajty.
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        if (bytes.isEmpty) continue;

        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename: image.name,
          ),
        );
      } else {
        if (image.path.isEmpty) continue;

        request.files.add(
          await http.MultipartFile.fromPath(
            'images',
            image.path,
            filename: image.name,
          ),
        );
      }
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
    // Nie nadpisuj Content-Type dla multipart/form-data.
    headers.remove('Content-Type');
    request.headers.addAll(headers);

    request.fields['Condition'] = condition;

    for (final image in images) {
      // Flutter Web: MultipartFile.fromPath wymaga dart:io, więc wysyłamy bajty.
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        if (bytes.isEmpty) continue;

        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename: image.name,
          ),
        );
      } else {
        if (image.path.isEmpty) continue;

        request.files.add(
          await http.MultipartFile.fromPath(
            'images',
            image.path,
            filename: image.name,
          ),
        );
      }
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
