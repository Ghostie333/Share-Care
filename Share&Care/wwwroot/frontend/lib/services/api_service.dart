import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
	static const String _baseUrl = 'http://192.168.122.1:7070';

	static Uri _uri(String path) => Uri.parse('$_baseUrl$path');

	static Future<http.Response> get(String path) {
		return http.get(_uri(path));
	}

	static Future<http.Response> delete(String path) {
		return http.delete(_uri(path));
	}

	static Future<http.Response> postJson(String path, Map<String, dynamic> body) {
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
