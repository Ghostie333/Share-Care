import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:frontend/config/app_config.dart';

class ApiService {
	static const String _baseUrl = AppConfig.apiBaseUrl;

	static Uri _uri(String path) => Uri.parse('$_baseUrl$path');

	// Helper do tworzenia headers z tokenem JWT
	static Map<String, String> _getHeaders({bool includeAuth = true}) {
		final headers = {'Content-Type': 'application/json'};

		// Dodaj token JWT jeśli istnieje
		if (includeAuth) {
			final token = html.window.localStorage['jwt_token'];
			if (token != null && token.isNotEmpty) {
				headers['Authorization'] = 'Bearer $token';
			}
		}

		return headers;
	}

	static Future<http.Response> postJson(String path, Map<String, dynamic> body, {bool includeAuth = true}) {
		return http.post(
			_uri(path),
			headers: _getHeaders(includeAuth: includeAuth),
			body: jsonEncode(body),
		);
	}

	static Future<http.Response> get(String path) {
		return http.get(
			_uri(path),
			headers: _getHeaders(),
		);
	}
}
