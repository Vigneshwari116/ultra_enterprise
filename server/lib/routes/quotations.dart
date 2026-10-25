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
    WHEN q.data::jsonb->>'party_kind' = 'SUPPLIER' THEN (
      SELECT data::jsonb->>'supplier_name' FROM suppliers
      WHERE id = (q.data::jsonb->>'party_id')::int
    )
    WHEN q.data::jsonb->>'party_kind' = 'CUSTOMER' THEN (
      SELECT customer_name FROM customers
      WHERE id = (q.data::jsonb->>'party_id')::int
    )
    ELSE COALESCE(q.data::jsonb->>'party_name', '-')
  END AS party_name
''';

void registerQuotationRoutes(Router router, Connection conn) {
  router.get('/api/quotations', (_) => listQuotations(conn));
  router.post('/api/quotations', (r) => createQuotation(r, conn));
  router.get('/api/quotations/<id>', (Request _, String id) async {
    final qid = int.tryParse(id);
    if (qid == null) return jsonError('Invalid quotation id', status: 400);
    return getQuotationById(conn, qid);
  });
  router.put('/api/quotations/<id>/status', (Request r, String id) async {
    final qid = int.tryParse(id);
    if (qid == null) return jsonError('Invalid quotation id', status: 400);
    return updateQuotationStatus(r, conn, qid);
  });
}

Future<Response> listQuotations(Connection conn) async {
  final rows = await conn.execute('''
    SELECT q.id, q.uuid, q.status, q.data, q.created_at,
      $_partyNameSql,
      (
        SELECT COALESCE(SUM((qi.data::jsonb->>'quantity')::numeric), 0)
        FROM quotation_items qi
        WHERE qi.parent_id = q.id
      ) AS total_qty
    FROM quotations q
    ORDER BY (q.data::jsonb->>'quotation_date') DESC NULLS LAST, q.id DESC
  ''');
  final list = rows.map((r) {
    final flat = flattenEnvelopeRow(serializeRow(r.toColumnMap()));
    final partyName = r.toColumnMap()['party_name'];
    if (partyName != null) flat['party_name'] = partyName;
    return flat;
  }).toList();
  return jsonOk(serializeRows(list));
}

Future<Response> getQuotationById(Connection conn, int id) async {
  final rows = await conn.execute(
    Sql.named('''
      SELECT q.id, q.uuid, q.status, q.data, q.created_at, $_partyNameSql
      FROM quotations q WHERE q.id = @id
    '''),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonError('Quotation not found: $id', status: 404);
  final quotation = flattenEnvelopeRow(serializeRow(rows.first.toColumnMap()));
  final items = await conn.execute(
    Sql.named('SELECT id, parent_id, data FROM quotation_items WHERE parent_id = @id ORDER BY id'),
    parameters: {'id': id},
  );
  final terms = await conn.execute(
    Sql.named('SELECT id, parent_id, data FROM quotation_terms WHERE parent_id = @id ORDER BY id'),
    parameters: {'id': id},
  );
  return jsonOk({
    'quotation': quotation,
    'items': items.map((r) => flattenEnvelopeRow(serializeRow(r.toColumnMap()))).toList(),
    'terms': terms.map((r) => flattenEnvelopeRow(serializeRow(r.toColumnMap()))).toList(),
  });
}

Future<Response> createQuotation(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final items = asItemList(body.remove('items'));
  final terms = asItemList(body.remove('terms'));
  if (items.isEmpty) return jsonError('Quotation must contain at least one item');

  return await conn.runTx((tx) async {
    final status = '${body['status'] ?? 'PENDING'}';
    final payload = jsonEncode(body);
    final result = await tx.execute(
      Sql.named('''
        INSERT INTO quotations (uuid, status, data, created_at)
        VALUES (@uuid, @status, @data, NOW())
        RETURNING id
      '''),
      parameters: {
        'uuid': body['uuid'] ?? _uuid.v4(),
        'status': status,
        'data': payload,
      },
    );
    final qid = (result.first.first as num).toInt();
    for (final it in items) {
      await tx.execute(
        Sql.named('''
          INSERT INTO quotation_items (parent_id, data)
          VALUES (@parent_id, @data)
        '''),
        parameters: {'parent_id': qid, 'data': jsonEncode(it)},
      );
    }
    var sort = 0;
    for (final t in terms) {
      await tx.execute(
        Sql.named('''
          INSERT INTO quotation_terms (parent_id, data)
          VALUES (@parent_id, @data)
        '''),
        parameters: {
          'parent_id': qid,
          'data': jsonEncode({...t, 'sort_order': t['sort_order'] ?? sort++}),
        },
      );
    }
    return jsonOk({'id': qid, 'quotation': {'id': qid}}, status: 201);
  });
}

Future<Response> updateQuotationStatus(Request request, Connection conn, int id) async {
  final body = await readJsonObject(request);
  final status = body['status'];
  if (status == null) return jsonError('status is required');
  final updated = await conn.execute(
    Sql.named('UPDATE quotations SET status = @status WHERE id = @id RETURNING id'),
    parameters: {'id': id, 'status': status},
  );
  if (updated.isEmpty) return jsonError('Quotation not found: $id', status: 404);
  return jsonOk({'id': id, 'status': status});
}
