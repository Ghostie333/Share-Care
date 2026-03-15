import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiService {
	static String get _baseUrl => AppConfig.apiBaseUrl;

	static Uri _uri(String path) => Uri.parse('$_baseUrl$path');

	static Future<http.Response> get(String path) {
		return http.get(_uri(path));
	}

	static Future<http.Response> delete(String path) {
		return http.delete(_uri(path));
	}

	static Future<http.Response> postJson(
		String path,
		Map<String, dynamic> body, {
		bool includeAuth = true,
	}) {
		// Na razie flaga jest tylko po to, żeby wywołania z `includeAuth: false`
		// kompilowały się poprawnie. Dodanie nagłówka Authorization możesz
		// dopisać później, jeśli będzie potrzebne.
		return http.post(
			_uri(path),
			headers: const {'Content-Type': 'application/json'},
			body: jsonEncode(body),
		);
	}

	static Future<http.Response> putJson(String path, Map<String, dynamic> body) {
		return http.put(
			_uri(path),
			headers: const {'Content-Type': 'application/json'},
			body: jsonEncode(body),
		);
	}
}