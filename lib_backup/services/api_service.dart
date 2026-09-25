import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Change this to the public HTTPS URL of the Ultra VPS API.
  static const String baseUrl = 'http://127.0.0.1:8081';

  Future<dynamic> get(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'));
    return _decode(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body);
  }
}
