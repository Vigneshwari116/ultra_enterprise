import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../http.dart';
import '../json_util.dart';

const _uuid = Uuid();

const _partyNameSql = '''
  CASE
    WHEN an.data::jsonb->>'party_kind' = 'SUPPLIER' THEN (
      SELECT data::jsonb->>'supplier_name' FROM suppliers
      WHERE id = (an.data::jsonb->>'party_id')::int
    )
    WHEN an.data::jsonb->>'party_kind' = 'CUSTOMER' THEN (
      SELECT customer_name FROM customers
      WHERE id = (an.data::jsonb->>'party_id')::int
    )
    ELSE COALESCE(an.data::jsonb->>'party_name', '-')
  END AS party_name
''';

void registerAdjustmentNoteRoutes(Router router, Connection conn) {
  router.get('/api/adjustment-notes', (Request request) => listAdjustmentNotes(request, conn));
  router.post('/api/adjustment-notes', (r) => createAdjustmentNote(r, conn));
  router.get('/api/adjustment-notes/<id>', (Request _, String id) async {
    final nid = int.tryParse(id);
    if (nid == null) return jsonError('Invalid adjustment note id', status: 400);
    return getAdjustmentNoteById(conn, nid);
  });
}

Future<Response> listAdjustmentNotes(Request request, Connection conn) async {
  final noteType = request.url.queryParameters['note_type'];
  final where = noteType == null ? '' : "WHERE an.note_type = @note_type";
  final rows = await conn.execute(
    Sql.named('''
      SELECT an.id, an.uuid, an.note_type, an.status, an.data, an.created_at,
        $_partyNameSql
      FROM adjustment_notes an
      $where
      ORDER BY (an.data::jsonb->>'issue_date') DESC NULLS LAST, an.id DESC
    '''),
    parameters: noteType == null ? {} : {'note_type': noteType},
  );
  final list = rows.map((r) {
    final flat = flattenEnvelopeRow(serializeRow(r.toColumnMap()));
    final partyName = r.toColumnMap()['party_name'];
    if (partyName != null) flat['party_name'] = partyName;
    return flat;
  }).toList();
  return jsonOk(serializeRows(list));
}

Future<Response> getAdjustmentNoteById(Connection conn, int id) async {
  final rows = await conn.execute(
    Sql.named('''
      SELECT an.id, an.uuid, an.note_type, an.status, an.data, an.created_at, $_partyNameSql
      FROM adjustment_notes an WHERE an.id = @id
    '''),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonError('Adjustment note not found: $id', status: 404);
  final note = flattenEnvelopeRow(serializeRow(rows.first.toColumnMap()));
  final items = await conn.execute(
    Sql.named('SELECT id, parent_id, data FROM adjustment_note_items WHERE parent_id = @id ORDER BY id'),
    parameters: {'id': id},
  );
  return jsonOk({
    'note': note,
    'items': items.map((r) => flattenEnvelopeRow(serializeRow(r.toColumnMap()))).toList(),
  });
}

Future<Response> createAdjustmentNote(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final items = asItemList(body.remove('items'));
  if (items.isEmpty) return jsonError('Adjustment note must contain at least one item');

  return await conn.runTx((tx) async {
    final noteType = '${body['note_type']}';
    final status = '${body['status'] ?? 'POSTED'}';
    final payload = jsonEncode(body);
    final result = await tx.execute(
      Sql.named('''
        INSERT INTO adjustment_notes (uuid, note_type, status, data, created_at)
        VALUES (@uuid, @note_type, @status, @data, COALESCE(@created_at::timestamptz, NOW()))
        RETURNING id
      '''),
      parameters: {
        'uuid': body['uuid'] ?? _uuid.v4(),
        'note_type': noteType,
        'status': status,
        'data': payload,
        'created_at': body['created_at'],
      },
    );
    final noteId = (result.first.first as num).toInt();
    for (final it in items) {
      await tx.execute(
        Sql.named('''
          INSERT INTO adjustment_note_items (parent_id, data)
          VALUES (@parent_id, @data)
        '''),
        parameters: {'parent_id': noteId, 'data': jsonEncode(it)},
      );
    }
    return jsonOk({'id': noteId, 'note': {'id': noteId}}, status: 201);
  });
}
