import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  static const _cannotReachServer = 'Cannot reach server';

  String get baseUrl => UltraConfig.apiBaseUrl;

  Future<dynamic> get(String path) async {
    return _request(() => http.get(Uri.parse('$baseUrl$path')));
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    return _request(
      () => http.post(
        Uri.parse('$baseUrl$path'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    return _request(
      () => http.put(
        Uri.parse('$baseUrl$path'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );
  }

  Future<dynamic> delete(String path) async {
    return _request(
      () => http.delete(
        Uri.parse('$baseUrl$path'),
        headers: _jsonHeaders,
      ),
    );
  }

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  Future<dynamic> _request(Future<http.Response> Function() send) async {
    try {
      return _decode(await send());
    } on SocketException {
      throw ApiException(0, _cannotReachServer);
    } on http.ClientException {
      throw ApiException(0, _cannotReachServer);
    } on TimeoutException {
      throw ApiException(0, _cannotReachServer);
    }
  }

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
