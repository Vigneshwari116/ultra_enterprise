import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/ultra_config.dart';

/// Thrown when the API returns a non-success status; [message] is user-readable when possible.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.rawBody});

  final int statusCode;
  final String message;
  final String? rawBody;

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  String get baseUrl => UltraConfig.apiBaseUrl;

  Future<dynamic> get(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'));
    return _decode(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _jsonHeaders,
    );
    return _decode(response);
  }

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        _messageFromBody(response.statusCode, response.body),
        rawBody: response.body,
      );
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static String _messageFromBody(int statusCode, String body) {
    if (body.trim().isEmpty) {
      return 'Request failed (HTTP $statusCode).';
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err = decoded['error'] ?? decoded['message'];
        if (err != null && '$err'.trim().isNotEmpty) {
          return '$err';
        }
      }
    } catch (_) {}
    if (body.length > 280) {
      return '${body.substring(0, 280)}…';
    }
    return body;
  }
}
