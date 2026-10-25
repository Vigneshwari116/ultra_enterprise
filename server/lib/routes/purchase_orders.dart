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
    WHEN (po.data::jsonb->>'supplier_id') IS NOT NULL THEN (
      SELECT data::jsonb->>'supplier_name' FROM suppliers
      WHERE id = (po.data::jsonb->>'supplier_id')::int
    )
    ELSE NULL
  END AS party_name
''';

void registerPurchaseOrderRoutes(Router router, Connection conn) {
  router.get('/api/purchase-orders', (Request request) => listPurchaseOrders(request, conn));
  router.post('/api/purchase-orders', (r) => createPurchaseOrder(r, conn));
  router.get('/api/purchase-orders/<id>', (Request _, String id) async {
    final oid = int.tryParse(id);
    if (oid == null) return jsonError('Invalid purchase order id', status: 400);
    return getPurchaseOrderById(conn, oid);
  });
  router.put('/api/purchase-orders/<id>/status', (Request r, String id) async {
    final oid = int.tryParse(id);
    if (oid == null) return jsonError('Invalid purchase order id', status: 400);
    return updatePurchaseOrderStatus(r, conn, oid);
  });
}

Future<Response> listPurchaseOrders(Request request, Connection conn) async {
  final status = request.url.queryParameters['status'];
  final where = status == 'open' ? "WHERE po.status IS DISTINCT FROM 'RECEIVED'" : '';
  final rows = await conn.execute('''
    SELECT po.id, po.uuid, po.status, po.data, po.created_at,
      $_partyNameSql,
      (
        SELECT COALESCE(SUM((poi.data::jsonb->>'quantity')::numeric), 0)
        FROM purchase_order_items poi
        WHERE poi.parent_id = po.id
      ) AS total_qty
    FROM purchase_orders po
    $where
    ORDER BY (po.data::jsonb->>'po_date') DESC NULLS LAST, po.id DESC
  ''');
  final list = rows.map((r) {
    final flat = flattenEnvelopeRow(serializeRow(r.toColumnMap()));
    final partyName = r.toColumnMap()['party_name'];
    if (partyName != null && '$partyName'.trim().isNotEmpty) {
      flat['party_name'] = partyName;
      flat['supplier_name'] ??= partyName;
    }
    return flat;
  }).toList();
  return jsonOk(serializeRows(list));
}

Future<Response> getPurchaseOrderById(Connection conn, int id) async {
  final rows = await conn.execute(
    Sql.named('''
      SELECT po.id, po.uuid, po.status, po.data, po.created_at,
        $_partyNameSql,
        s.data::jsonb->>'supplier_name' AS supplier_name,
        s.data::jsonb->>'address' AS address,
        s.data::jsonb->>'city' AS city,
        s.data::jsonb->>'postal_pincode' AS postal_pincode,
        s.data::jsonb->>'gstin' AS gstin,
        s.data::jsonb->>'primary_mobile' AS primary_mobile,
        s.data::jsonb->>'bank_name' AS bank_name,
        s.data::jsonb->>'bank_account_no' AS bank_account_no,
        s.data::jsonb->>'ifsc_code' AS ifsc_code,
        s.data::jsonb->>'branch_address' AS branch_address
      FROM purchase_orders po
      LEFT JOIN suppliers s ON s.id = (po.data::jsonb->>'supplier_id')::int
      WHERE po.id = @id
    '''),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonError('Purchase order not found: $id', status: 404);
  final order = flattenEnvelopeRow(serializeRow(rows.first.toColumnMap()));
  final items = await conn.execute(
    Sql.named(
      'SELECT id, parent_id, data FROM purchase_order_items '
      'WHERE parent_id = @id ORDER BY id',
    ),
    parameters: {'id': id},
  );
  final itemRows = items
      .map((r) => flattenEnvelopeRow(serializeRow(r.toColumnMap())))
      .toList();
  return jsonOk({
    'order': order,
    'items': serializeRows(itemRows),
  });
}

Future<Response> createPurchaseOrder(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final items = asItemList(body.remove('items'));
  if (items.isEmpty) return jsonError('Purchase order must contain at least one item');

  return await conn.runTx((tx) async {
    final headerStatus = '${body['status'] ?? 'PENDING'}';
    final payload = jsonEncode(body);
    final result = await tx.execute(
      Sql.named('''
        INSERT INTO purchase_orders (uuid, status, data, created_at)
        VALUES (@uuid, @status, @data, NOW())
        RETURNING id
      '''),
      parameters: {
        'uuid': body['uuid'] ?? _uuid.v4(),
        'status': headerStatus,
        'data': payload,
      },
    );
    final orderId = (result.first.first as num).toInt();
    for (final it in items) {
      await tx.execute(
        Sql.named('''
          INSERT INTO purchase_order_items (parent_id, data)
          VALUES (@parent_id, @data)
        '''),
        parameters: {
          'parent_id': orderId,
          'data': jsonEncode(it),
        },
      );
    }
    return jsonOk({'id': orderId, 'order': {'id': orderId}}, status: 201);
  });
}

Future<Response> updatePurchaseOrderStatus(Request request, Connection conn, int id) async {
  final body = await readJsonObject(request);
  final status = body['status'];
  if (status == null) return jsonError('status is required');
  final updated = await conn.execute(
    Sql.named('UPDATE purchase_orders SET status = @status WHERE id = @id RETURNING id'),
    parameters: {'id': id, 'status': status},
  );
  if (updated.isEmpty) return jsonError('Purchase order not found: $id', status: 404);
  return jsonOk({'id': id, 'status': status});
}
