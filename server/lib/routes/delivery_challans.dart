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
    WHEN dc.data::jsonb->>'party_kind' = 'SUPPLIER' THEN (
      SELECT data::jsonb->>'supplier_name' FROM suppliers
      WHERE id = (dc.data::jsonb->>'party_id')::int
    )
    WHEN dc.data::jsonb->>'party_kind' = 'CUSTOMER' THEN (
      SELECT customer_name FROM customers
      WHERE id = (dc.data::jsonb->>'party_id')::int
    )
    ELSE COALESCE(dc.data::jsonb->>'party_name', '-')
  END AS party_name
''';

void registerDeliveryChallanRoutes(Router router, Connection conn) {
  router.get('/api/delivery-challans', (Request request) => listDeliveryChallans(request, conn));
  router.post('/api/delivery-challans', (r) => createDeliveryChallan(r, conn));
  router.get('/api/delivery-challans/<id>', (Request _, String id) async {
    final cid = int.tryParse(id);
    if (cid == null) return jsonError('Invalid delivery challan id', status: 400);
    return getDeliveryChallanById(conn, cid);
  });
}

Future<Response> listDeliveryChallans(Request request, Connection conn) async {
  final dcType = request.url.queryParameters['dc_type'];
  final where = dcType == null ? '' : 'WHERE dc.dc_type = @dc_type';
  final rows = await conn.execute(
    Sql.named('''
      SELECT dc.id, dc.uuid, dc.dc_type, dc.status, dc.data, dc.created_at,
        $_partyNameSql
      FROM delivery_challans dc
      $where
      ORDER BY (dc.data::jsonb->>'document_date') DESC NULLS LAST, dc.id DESC
    '''),
    parameters: dcType == null ? {} : {'dc_type': dcType},
  );
  final list = rows.map((r) {
    final flat = flattenEnvelopeRow(serializeRow(r.toColumnMap()));
    final partyName = r.toColumnMap()['party_name'];
    if (partyName != null && '$partyName'.trim().isNotEmpty) {
      flat['party_name'] = partyName;
    }
    return flat;
  }).toList();
  return jsonOk(serializeRows(list));
}

Future<Response> getDeliveryChallanById(Connection conn, int id) async {
  final rows = await conn.execute(
    Sql.named('''
      SELECT dc.id, dc.uuid, dc.dc_type, dc.status, dc.data, dc.created_at,
        $_partyNameSql
      FROM delivery_challans dc WHERE dc.id = @id
    '''),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonError('Delivery challan not found: $id', status: 404);
  final header = flattenEnvelopeRow(serializeRow(rows.first.toColumnMap()));
  final partyName = rows.first.toColumnMap()['party_name'];
  if (partyName != null && '$partyName'.trim().isNotEmpty) {
    header['party_name'] = partyName;
  }
  final items = await conn.execute(
    Sql.named('SELECT id, parent_id, data, created_at FROM delivery_challan_items WHERE parent_id = @id ORDER BY id'),
    parameters: {'id': id},
  );
  final itemRows = items
      .map((r) => flattenEnvelopeRow(serializeRow(r.toColumnMap())))
      .toList();
  return jsonOk({
    'challan': header,
    'items': serializeRows(itemRows),
  });
}

Future<Response> createDeliveryChallan(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final items = asItemList(body.remove('items'));
  if (items.isEmpty) return jsonError('Delivery challan must contain at least one item');

  try {
    return await conn.runTx((tx) async {
      final dcType = '${body['dc_type']}';
      final headerData = Map<String, dynamic>.from(body);
      final payload = jsonEncode(headerData);
      final result = await tx.execute(
        Sql.named('''
          INSERT INTO delivery_challans (uuid, dc_type, status, data, created_at)
          VALUES (@uuid, @dc_type, @status, @data, NOW())
          RETURNING id
        '''),
        parameters: {
          'uuid': body['uuid'] ?? _uuid.v4(),
          'dc_type': dcType,
          'status': body['status'] ?? 'POSTED',
          'data': payload,
        },
      );
      final challanId = (result.first.first as num).toInt();
      if (dcType == 'OUTWARD') {
        for (final it in items) {
          final productId = _asInt(it['product_id']);
          final qty = _num(it['quantity']) ?? 0;
          if (productId == null || qty <= 0) continue;
          final available = await _stockOnHand(tx, productId);
          if (qty > available) {
            throw StateError(
              'Insufficient stock for product $productId: available $available, requested $qty',
            );
          }
        }
      }
      for (final it in items) {
        await tx.execute(
          Sql.named('''
            INSERT INTO delivery_challan_items (parent_id, data, created_at)
            VALUES (@parent_id, @data, NOW())
          '''),
          parameters: {
            'parent_id': challanId,
            'data': jsonEncode(it),
          },
        );
        final productId = _asInt(it['product_id']);
        final qty = _num(it['quantity']) ?? 0;
        if (productId == null || qty <= 0) continue;
        if (dcType == 'INWARD') {
          await _adjustStock(tx, productId, qty);
        } else if (dcType == 'OUTWARD') {
          await _adjustStock(tx, productId, -qty);
        }
      }
      return jsonOk({'id': challanId, 'challan': {'id': challanId}}, status: 201);
    });
  } on StateError catch (e) {
    return jsonError(e.message, status: 400);
  }
}

Future<num> _stockOnHand(Session session, int productId) async {
  final rows = await session.execute(
    Sql.named('SELECT quantity FROM stock WHERE product_id = @id'),
    parameters: {'id': productId},
  );
  if (rows.isEmpty) return 0;
  return rows.first.toColumnMap()['quantity'] as num? ?? 0;
}

Future<void> _adjustStock(Session session, int productId, num delta) async {
  await session.execute(
    Sql.named('''
      INSERT INTO stock (product_id, quantity)
      VALUES (@product_id, @delta)
      ON CONFLICT (product_id)
      DO UPDATE SET quantity = stock.quantity + @delta, updated_at = NOW()
    '''),
    parameters: {'product_id': productId, 'delta': delta},
  );
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value'.trim());
}

num? _num(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse('$value'.trim());
}
