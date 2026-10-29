import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/ultra_config.dart';

/// Thrown when the API returns a non-success status; [message] is user-readable when possible.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.rawBody, this.code});

  final int statusCode;
  final String message;
  final String? rawBody;
  final String? code;

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _cannotReachServer = 'Cannot reach server';

  /// Set from app startup. Clears the saved token on session_* / user_disabled.
  void Function(String message)? onSessionRejected;

  String get baseUrl => UltraConfig.apiBaseUrl;

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    final token = _bearerToken?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Supplies the in-memory bearer token. Wired from app startup.
  String? Function()? _bearerToken;

  void bindToken(String? Function() readToken) {
    _bearerToken = readToken;
  }

  Future<dynamic> get(String path) async {
    return _request(() => http.get(Uri.parse('$baseUrl$path'), headers: _headers()));
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    return _request(
      () => http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
    );
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    return _request(
      () => http.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
    );
  }

  Future<dynamic> delete(String path) async {
    return _request(
      () => http.delete(
        Uri.parse('$baseUrl$path'),
        headers: _headers(json: true),
      ),
    );
  }

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
      final code = _codeFromBody(response.body);
      final message = _messageFromBody(response.statusCode, response.body);
      if (response.statusCode == 401 &&
          code != null &&
          (code.startsWith('session_') || code == 'user_disabled')) {
        onSessionRejected?.call(message);
      }
      throw ApiException(
        response.statusCode,
        message,
        rawBody: response.body,
        code: code,
      );
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static String? _codeFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['code'] != null) {
        final code = '${decoded['code']}'.trim();
        if (code.isNotEmpty) return code;
      }
    } catch (_) {}
    return null;
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
