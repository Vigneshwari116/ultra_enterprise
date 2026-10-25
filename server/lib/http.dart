import 'dart:convert';

import 'package:shelf/shelf.dart';

Map<String, String> jsonHeaders = const {'content-type': 'application/json; charset=utf-8'};

Response jsonOk(Object? body, {int status = 200}) {
  return Response(status, body: jsonEncode(body), headers: jsonHeaders);
}

Response jsonError(String message, {int status = 400}) {
  return Response(status, body: jsonEncode({'error': message}), headers: jsonHeaders);
}

Future<Map<String, dynamic>> readJsonObject(Request request) async {
  final raw = await request.readAsString();
  if (raw.trim().isEmpty) return {};
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  throw const FormatException('JSON object required');
}

List<Map<String, dynamic>> asItemList(dynamic items) {
  if (items is! List) return [];
  return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

Map<String, dynamic> serializeRow(Map<String, dynamic> row) {
  return row.map((k, v) {
    if (v is DateTime) return MapEntry(k, v.toIso8601String());
    return MapEntry(k, v);
  });
}

List<Map<String, dynamic>> serializeRows(List<Map<String, dynamic>> rows) {
  return rows.map(serializeRow).toList();
}
