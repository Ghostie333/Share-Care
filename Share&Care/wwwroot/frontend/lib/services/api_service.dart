import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';

class ApiService {
	static String get _baseUrl => AppConfig.apiBaseUrl;
	static String get apiBaseUrl => _baseUrl;

	static Uri _uri(String path) => Uri.parse('$_baseUrl$path');

	static Future<http.Response> _handleResponse(
		http.Response response,
	) async {
		if (response.statusCode == 401) {
			await AuthService.logout();
		}
		return response;
	}

	static Future<http.Response> get(
		String path, {
		bool includeAuth = true,
	}) async {
		final headers = await buildHeaders(includeAuth: includeAuth);
		final response = await http.get(_uri(path), headers: headers);
		return _handleResponse(response);
	}

	static Future<http.Response> delete(
		String path, {
		bool includeAuth = true,
	}) async {
		final headers = await buildHeaders(includeAuth: includeAuth);
		final response = await http.delete(_uri(path), headers: headers);
		return _handleResponse(response);
	}

	static Future<http.Response> postJson(
		String path,
		Map<String, dynamic> body, {
		bool includeAuth = true,
	}) async {
		final headers = await buildHeaders(
			includeAuth: includeAuth,
		);
		headers.putIfAbsent('Content-Type', () => 'application/json');
		final response = await http.post(
			_uri(path),
			headers: headers,
			body: jsonEncode(body),
		);
		return _handleResponse(response);
	}

	static Future<http.Response> putJson(
		String path,
		Map<String, dynamic> body, {
		bool includeAuth = true,
	}) async {
		final headers = await buildHeaders(
			includeAuth: includeAuth,
		);
		headers.putIfAbsent('Content-Type', () => 'application/json');
		final response = await http.put(
			_uri(path),
			headers: headers,
			body: jsonEncode(body),
		);
		return _handleResponse(response);
	}

	static Future<Map<String, String>> buildHeaders({
		required bool includeAuth,
	}) async {
		final headers = <String, String>{};
		headers['Content-Type'] = 'application/json';
		if (includeAuth) {
			final token = await AuthService.getToken();
			if (token != null && token.isNotEmpty) {
				headers['Authorization'] = 'Bearer $token';
			}
		}
		return headers;
	}
}