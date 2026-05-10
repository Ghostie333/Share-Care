import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class RewardItem {
	final String id;
	final String name;
	final String description;
	final int cost;

	const RewardItem({
		required this.id,
		required this.name,
		required this.description,
		required this.cost,
	});

	factory RewardItem.fromJson(Map<String, dynamic> json) {
		return RewardItem(
			id: (json['id'] ?? '').toString(),
			name: (json['name'] ?? '').toString(),
			description: (json['description'] ?? '').toString(),
			cost: int.tryParse((json['cost'] ?? 0).toString()) ?? 0,
		);
	}
}

class RewardsService {
	RewardsService._();

	static Future<List<RewardItem>> fetchRewards() async {
		final http.Response res = await ApiService.get('/rewards/list', includeAuth: false);
		if (res.statusCode != 200) {
			throw Exception('Błąd pobierania nagród: ${res.statusCode}');
		}

		final decoded = jsonDecode(res.body) as List<dynamic>;
		return decoded
				.map((e) => RewardItem.fromJson(e as Map<String, dynamic>))
				.toList();
	}

	static Future<int> redeemReward(String rewardId) async {
		final http.Response res = await ApiService.postJson(
			'/rewards/redeem',
			{'RewardId': rewardId},
		);

		if (res.statusCode != 200) {
			throw Exception('Błąd realizacji nagrody: ${res.statusCode} ${res.body}');
		}

		final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
		return int.tryParse((data['credits'] ?? 0).toString()) ?? 0;
	}
}
