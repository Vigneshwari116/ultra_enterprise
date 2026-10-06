import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../http.dart';
import '../json_util.dart';

const _uuid = Uuid();

void registerCustomerSupplierRoutes(Router router, Connection conn) {
  router.post('/api/customers', (r) => createCustomer(r, conn));
  router.put('/api/customers/<id>', (Request r, String id) async {
    final cid = int.tryParse(id);
    if (cid == null) return jsonError('Invalid customer id', status: 400);
    return updateCustomer(r, conn, cid);
  });

  router.get('/api/suppliers/<id>', (Request _, String id) async {
    final sid = int.tryParse(id);
    if (sid == null) return jsonError('Invalid supplier id', status: 400);
    return getSupplier(conn, sid);
  });
  router.post('/api/suppliers', (r) => createSupplier(r, conn));
  router.put('/api/suppliers/<id>', (Request r, String id) async {
    final sid = int.tryParse(id);
    if (sid == null) return jsonError('Invalid supplier id', status: 400);
    return updateSupplier(r, conn, sid);
  });
}

Future<Response> createCustomer(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  if ('${body['customer_name'] ?? ''}'.trim().isEmpty) {
    return jsonError('customer_name is required');
  }
  final code = body['customer_code'] ?? 'CUST-${DateTime.now().millisecondsSinceEpoch % 100000}';
  final result = await conn.execute(
    Sql.named(
      'INSERT INTO customers (uuid, customer_code, customer_name, address, city, postal_pincode, gstin, '
      'bank_identifier_name, bank_account_no, shipping_address, primary_mobile, email, '
      'opening_balance_cr, opening_balance_dr, ifsc_code, branch_address, shipping_consignee_name, '
      'shipping_contact_mobile, shipping_city, shipping_pincode, shipping_gstin, is_active) '
      'VALUES (@uuid, @customer_code, @customer_name, @address, @city, @postal_pincode, @gstin, '
      '@bank_identifier_name, @bank_account_no, @shipping_address, @primary_mobile, @email, '
      '@opening_balance_cr, @opening_balance_dr, @ifsc_code, @branch_address, @shipping_consignee_name, '
      '@shipping_contact_mobile, @shipping_city, @shipping_pincode, @shipping_gstin, true) '
      'RETURNING id',
    ),
    parameters: _customerParams(body, code),
  );
  final id = result.first.first;
  return jsonOk({'id': id, 'customer': {'id': id}}, status: 201);
}

Map<String, dynamic> _customerParams(Map<String, dynamic> body, String code) {
  return {
    'uuid': _uuid.v4(),
    'customer_code': code,
    'customer_name': body['customer_name'],
    'address': body['address'],
    'city': body['city'],
    'postal_pincode': body['postal_pincode'],
    'gstin': body['gstin'],
    'bank_identifier_name': body['bank_identifier_name'] ?? body['bank_name'],
    'bank_account_no': body['bank_account_no'],
    'shipping_address': body['shipping_address'],
    'primary_mobile': body['primary_mobile'],
    'email': body['email'],
    'opening_balance_cr': body['opening_balance_cr'] ?? 0,
    'opening_balance_dr': body['opening_balance_dr'] ?? 0,
    'ifsc_code': body['ifsc_code'],
    'branch_address': body['branch_address'],
    'shipping_consignee_name': body['shipping_consignee_name'],
    'shipping_contact_mobile': body['shipping_contact_mobile'],
    'shipping_city': body['shipping_city'],
    'shipping_pincode': body['shipping_pincode'],
    'shipping_gstin': body['shipping_gstin'],
  };
}

Future<Response> updateCustomer(Request request, Connection conn, int id) async {
  final body = await readJsonObject(request);
  final updated = await conn.execute(
    Sql.named(
      'UPDATE customers SET '
      'customer_name = COALESCE(@customer_name, customer_name), '
      'address = COALESCE(@address, address), city = COALESCE(@city, city), '
      'postal_pincode = COALESCE(@postal_pincode, postal_pincode), '
      'gstin = COALESCE(@gstin, gstin), '
      'primary_mobile = COALESCE(@primary_mobile, primary_mobile), '
      'email = COALESCE(@email, email), '
      'bank_identifier_name = COALESCE(@bank_identifier_name, bank_identifier_name), '
      'bank_account_no = COALESCE(@bank_account_no, bank_account_no), '
      'shipping_address = COALESCE(@shipping_address, shipping_address), '
      'updated_at = NOW() WHERE id = @id RETURNING id',
    ),
    parameters: {
      'id': id,
      'customer_name': body['customer_name'],
      'address': body['address'],
      'city': body['city'],
      'postal_pincode': body['postal_pincode'],
      'gstin': body['gstin'],
      'primary_mobile': body['primary_mobile'],
      'email': body['email'],
      'bank_identifier_name': body['bank_identifier_name'] ?? body['bank_name'],
      'bank_account_no': body['bank_account_no'],
      'shipping_address': body['shipping_address'],
    },
  );
  if (updated.isEmpty) return jsonError('Customer not found: $id', status: 404);
  return jsonOk({'id': id});
}

Future<Response> getSupplier(Connection conn, int id) async {
  final rows = await conn.execute(
    Sql.named('SELECT id, uuid, status, data::text AS data, created_at FROM suppliers WHERE id = @id'),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonError('Supplier not found: $id', status: 404);
  final row = flattenEnvelopeRow(rows.first.toColumnMap());
  return jsonOk(row);
}

Future<Response> createSupplier(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  if ('${body['supplier_name'] ?? ''}'.trim().isEmpty) {
    return jsonError('supplier_name is required');
  }
  final payload = jsonEncode(body);
  final result = await conn.execute(
    Sql.named(
      "INSERT INTO suppliers (uuid, status, data) VALUES (@uuid, 'ACTIVE', @data::jsonb) RETURNING id",
    ),
    parameters: {'uuid': _uuid.v4(), 'data': payload},
  );
  final id = result.first.first;
  return jsonOk({'id': id, 'supplier': {'id': id}}, status: 201);
}

Future<Response> updateSupplier(Request request, Connection conn, int id) async {
  final body = await readJsonObject(request);
  final existing = await conn.execute(
    Sql.named('SELECT data::text AS data FROM suppliers WHERE id = @id'),
    parameters: {'id': id},
  );
  if (existing.isEmpty) return jsonError('Supplier not found: $id', status: 404);
  final merged = flattenEnvelopeRow({'data': existing.first.toColumnMap()['data']});
  merged.addAll(body);
  final payload = jsonEncode(merged);
  await conn.execute(
    Sql.named('UPDATE suppliers SET data = @data::jsonb, status = COALESCE(@status, status) WHERE id = @id'),
    parameters: {'id': id, 'data': payload, 'status': body['status']},
  );
  return jsonOk({'id': id});
}
