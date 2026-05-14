import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class WalletSnapshot {
  final double balance;
  final double lockedBalance;
  final double availableBalance;

  const WalletSnapshot({
    required this.balance,
    required this.lockedBalance,
    required this.availableBalance,
  });

  factory WalletSnapshot.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) =>
        double.tryParse((v ?? 0).toString()) ?? 0;

    return WalletSnapshot(
      balance: parseNum(json['balance'] ?? json['Balance']),
      lockedBalance: parseNum(json['lockedBalance'] ?? json['LockedBalance']),
      availableBalance:
          parseNum(json['availableBalance'] ?? json['AvailableBalance']),
    );
  }
}

class WalletService {
  WalletService._();

  static Future<WalletSnapshot> getMyWallet() async {
    final http.Response res = await ApiService.get('/wallet/me');

    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania portfela: ${res.statusCode} ${res.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    return WalletSnapshot.fromJson(data);
  }

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
