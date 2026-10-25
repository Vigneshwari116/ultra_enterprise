import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db_errors.dart';
import '../http.dart';

/// Validates unit create/update JSON. Returns an error message or null if valid.
String? validateUnitBody(Map<String, dynamic> body) {
  final code = '${body['code'] ?? ''}'.trim();
  if (code.isEmpty) return 'code is required';
  final name = '${body['name'] ?? ''}'.trim();
  if (name.isEmpty && '${body['description'] ?? ''}'.trim().isEmpty) {
    return 'name or description is required';
  }
  return null;
}

void registerUnitRoutes(Router router, Connection conn) {
  router.get('/api/units', (_) => listUnits(conn));
  router.post('/api/units', (r) => createUnit(r, conn));
  router.put('/api/units/<id>', (Request r, String id) async {
    final uid = int.tryParse(id);
    if (uid == null) return jsonError('Invalid unit id', status: 400);
    return updateUnit(r, conn, uid);
  });
  router.delete('/api/units/<id>', (Request _, String id) async {
    final uid = int.tryParse(id);
    if (uid == null) return jsonError('Invalid unit id', status: 400);
    return deleteUnit(conn, uid);
  });
}

/// Matches live `GET /api/units` (all rows, including inactive).
Future<Response> listUnits(Connection conn) async {
  final rows = await conn.execute('''
    SELECT id, code, name, is_active, created_at
    FROM units
    ORDER BY id
  ''');
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}

Future<Response> createUnit(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final validation = validateUnitBody(body);
  if (validation != null) return jsonError(validation);

  final code = '${body['code']}'.trim().toUpperCase();
  final name = _unitNameFromBody(body);
  final description = '${body['description'] ?? ''}'.trim();

  try {
    final result = await conn.execute(
      Sql.named('''
        INSERT INTO units (code, name, description, is_active, created_at)
        VALUES (@code, @name, @description, true, NOW())
        RETURNING id
      '''),
      parameters: {
        'code': code,
        'name': name,
        'description': description.isEmpty ? null : description,
      },
    );
    final id = result.first.first;
    return jsonOk({'id': id, 'unit': {'id': id}}, status: 201);
  } catch (e) {
    if (isPostgresUniqueViolation(e)) {
      return jsonError('Unit code already exists', status: 409);
    }
    rethrow;
  }
}

Future<Response> updateUnit(Request request, Connection conn, int id) async {
  final body = await readJsonObject(request);
  final validation = validateUnitBody(body);
  if (validation != null) return jsonError(validation);

  final code = '${body['code']}'.trim().toUpperCase();
  final name = _unitNameFromBody(body);
  final description = '${body['description'] ?? ''}'.trim();

  try {
    final updated = await conn.execute(
      Sql.named('''
        UPDATE units SET
          code = @code,
          name = @name,
          description = COALESCE(@description, description)
        WHERE id = @id
        RETURNING id
      '''),
      parameters: {
        'id': id,
        'code': code,
        'name': name,
        'description': description.isEmpty ? null : description,
      },
    );
    if (updated.isEmpty) return jsonError('Unit not found: $id', status: 404);
    return jsonOk({'id': id, 'unit': {'id': id}});
  } catch (e) {
    if (isPostgresUniqueViolation(e)) {
      return jsonError('Unit code already exists', status: 409);
    }
    rethrow;
  }
}

/// Deletes a unit when nothing references it; otherwise deactivates (`is_active = false`)
/// so historical `unit_id` values on products and documents stay valid.
Future<Response> deleteUnit(Connection conn, int id) async {
  final exists = await conn.execute(
    Sql.named('SELECT id FROM units WHERE id = @id'),
    parameters: {'id': id},
  );
  if (exists.isEmpty) return jsonError('Unit not found: $id', status: 404);

  final refs = await conn.execute(
    Sql.named('SELECT 1 FROM products WHERE unit_id = @id LIMIT 1'),
    parameters: {'id': id},
  );
  if (refs.isNotEmpty) {
    await conn.execute(
      Sql.named('UPDATE units SET is_active = false WHERE id = @id'),
      parameters: {'id': id},
    );
    return jsonOk({
      'id': id,
      'deleted': false,
      'deactivated': true,
      'message': 'Unit is referenced by products; marked inactive instead of hard delete.',
    });
  }

  await conn.execute(
    Sql.named('DELETE FROM units WHERE id = @id'),
    parameters: {'id': id},
  );
  return jsonOk({'id': id, 'deleted': true});
}

String _unitNameFromBody(Map<String, dynamic> body) {
  final name = '${body['name'] ?? ''}'.trim();
  if (name.isNotEmpty) return name;
  final desc = '${body['description'] ?? ''}'.trim();
  if (desc.isNotEmpty) return desc;
  return '${body['code']}'.trim();
}
