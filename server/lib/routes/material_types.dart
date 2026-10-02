import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http.dart';

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
  final rows = await conn.execute('SELECT * FROM material_types ORDER BY type_code');
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}

Future<Response> createMaterialType(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  if ('${body['type_code'] ?? ''}'.trim().isEmpty) {
    return jsonError('type_code is required');
  }
  final result = await conn.execute(
    Sql.named('''
      INSERT INTO material_types (type_code, description, created_at)
      VALUES (@type_code, @description, NOW())
      RETURNING id
    '''),
    parameters: {
      'type_code': body['type_code'],
      'description': body['description'],
    },
  );
  final id = result.first.first;
  return jsonOk({'id': id, 'material_type': {'id': id}}, status: 201);
}

Future<Response> updateMaterialType(Request request, Connection conn, int id) async {
  final body = await readJsonObject(request);
  final updated = await conn.execute(
    Sql.named('''
      UPDATE material_types SET
        type_code = COALESCE(@type_code, type_code),
        description = COALESCE(@description, description)
      WHERE id = @id RETURNING id
    '''),
    parameters: {
      'id': id,
      'type_code': body['type_code'],
      'description': body['description'],
    },
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
