import 'dart:convert';

Map<String, dynamic> decodeJsonMap(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return {};
}

Map<String, dynamic> flattenEnvelopeRow(Map<String, dynamic> row) {
  final out = Map<String, dynamic>.from(row);
  final data = out.remove('data');
  Map<String, dynamic>? inner;
  if (data is String && data.trim().isNotEmpty) {
    try {
      inner = decodeJsonMap(data);
    } catch (_) {}
  } else if (data is Map) {
    inner = Map<String, dynamic>.from(data);
  }
  if (inner != null) {
    for (final e in inner.entries) {
      out.putIfAbsent(e.key, () => e.value);
    }
  }
  return out;
}

String jsonResponse(Object? body, {int status = 200}) {
  return jsonEncode(body);
}
