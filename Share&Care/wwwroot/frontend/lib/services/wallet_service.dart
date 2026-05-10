import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class WalletService {
  WalletService._();

  static Future<double> withdraw({required double amount}) async {
    final uriAmount = amount.toStringAsFixed(2);
    final http.Response res = await ApiService.postJson(
      '/wallet/withdraw?amount=$uriAmount',
      {},
    );

    if (res.statusCode != 200) {
      throw Exception('Błąd wypłaty: ${res.statusCode} ${res.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    return double.tryParse((data['balance'] ?? 0).toString()) ?? 0;
  }
}
