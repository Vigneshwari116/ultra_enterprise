import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../http.dart';
import '../json_util.dart';

const _uuid = Uuid();

void registerMaterialTypeRoutes(Router router, Connection conn) {
  router.get('/api/material-types', (_) => listMaterialTypes(conn));
  router.post('/api/material-types', (r) => createMaterialType(r, conn));
  router.put('/api/material-types/<id>', (Request r, String id) async {
    final mid = int.tryParse(id);
    if (mid == null) return jsonError('Invalid material type id', status: 400);
    return updateMaterialType(r, conn, mid);
  });
  router.delete('/api/material-types/<id>', (Request _, String id) async {
    final mid = int.tryParse(id);
    if (mid == null) return jsonError('Invalid material type id', status: 400);
    return deleteMaterialType(conn, mid);
  });
}

Future<Response> listMaterialTypes(Connection conn) async {
  final rows = await conn.execute(
    "SELECT id, uuid, status, data, created_at FROM material_types "
    "ORDER BY data::jsonb->>'type_code' ASC NULLS LAST, id ASC",
  );
  final list = rows
      .map((r) => flattenEnvelopeRow(serializeRow(r.toColumnMap())))
      .toList();
  return jsonOk(serializeRows(list));
}

Future<Response> createMaterialType(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  if ('${body['type_code'] ?? ''}'.trim().isEmpty) {
    return jsonError('type_code is required');
  }
  final payload = jsonEncode({
    'type_code': body['type_code'],
    'description': body['description'],
  });
  final result = await conn.execute(
    Sql.named('''
      INSERT INTO material_types (uuid, status, data, created_at)
      VALUES (@uuid, 'ACTIVE', @data, NOW())
      RETURNING id
    '''),
    parameters: {'uuid': _uuid.v4(), 'data': payload},
  );
  final id = result.first.first;
  return jsonOk({'id': id, 'material_type': {'id': id}}, status: 201);
}

Future<Response> updateMaterialType(Request request, Connection conn, int id) async {
  final body = await readJsonObject(request);
  final existing = await conn.execute(
    Sql.named('SELECT data FROM material_types WHERE id = @id'),
    parameters: {'id': id},
  );
  if (existing.isEmpty) return jsonError('Material type not found: $id', status: 404);
  final merged = flattenEnvelopeRow({'data': existing.first.toColumnMap()['data']});
  if (body['type_code'] != null) merged['type_code'] = body['type_code'];
  if (body.containsKey('description')) merged['description'] = body['description'];
  final updated = await conn.execute(
    Sql.named('UPDATE material_types SET data = @data WHERE id = @id RETURNING id'),
    parameters: {'id': id, 'data': jsonEncode(merged)},
  );
  if (updated.isEmpty) return jsonError('Material type not found: $id', status: 404);
  return jsonOk({'id': id});
}

Future<Response> deleteMaterialType(Connection conn, int id) async {
  final deleted = await conn.execute(
    Sql.named('DELETE FROM material_types WHERE id = @id RETURNING id'),
    parameters: {'id': id},
  );
  if (deleted.isEmpty) return jsonError('Material type not found: $id', status: 404);
  return jsonOk({'id': id});
}
