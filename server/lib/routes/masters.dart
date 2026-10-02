import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

import '../json_util.dart';

const _uuid = Uuid();

Future<Response> listCustomers(Connection conn) async {
  final rows = await conn.execute('SELECT * FROM customers ORDER BY id');
  final list = rows.map((r) => r.toColumnMap()).toList();
  return Response.ok(jsonEncode(list), headers: {'content-type': 'application/json'});
}

Future<Response> createCustomer(Request request, Connection conn) async {
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
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
    parameters: {
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
    },
  );
  final id = result.first.first;
  return Response(201, body: jsonEncode({'id': id, 'customer': {'id': id}}), headers: {'content-type': 'application/json'});
}

Future<Response> updateCustomer(Request request, Connection conn, int id) async {
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  await conn.execute(
    Sql.named(
      'UPDATE customers SET customer_name = COALESCE(@customer_name, customer_name), '
      'address = COALESCE(@address, address), city = COALESCE(@city, city), '
      'postal_pincode = COALESCE(@postal_pincode, postal_pincode), gstin = COALESCE(@gstin, gstin), '
      'primary_mobile = COALESCE(@primary_mobile, primary_mobile), email = COALESCE(@email, email), '
      'updated_at = NOW() WHERE id = @id',
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
    },
  );
  return Response.ok(jsonEncode({'id': id}), headers: {'content-type': 'application/json'});
}

Future<Response> listSuppliers(Connection conn) async {
  final rows = await conn.execute('SELECT id, uuid, status, data::text AS data, created_at FROM suppliers ORDER BY id');
  final list = rows.map((r) => r.toColumnMap()).toList();
  return Response.ok(jsonEncode(list), headers: {'content-type': 'application/json'});
}

Future<Response> getSupplier(Connection conn, int id) async {
  final rows = await conn.execute(
    Sql.named('SELECT id, uuid, status, data::text AS data, created_at FROM suppliers WHERE id = @id'),
    parameters: {'id': id},
  );
  if (rows.isEmpty) {
    return Response.notFound(jsonEncode({'error': 'Supplier not found: $id'}));
  }
  final row = flattenEnvelopeRow(rows.first.toColumnMap());
  return Response.ok(jsonEncode(row), headers: {'content-type': 'application/json'});
}

Future<Response> createSupplier(Request request, Connection conn) async {
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final payload = jsonEncode(body);
  final result = await conn.execute(
    Sql.named(
      "INSERT INTO suppliers (uuid, status, data) VALUES (@uuid, 'ACTIVE', @data::jsonb) RETURNING id",
    ),
    parameters: {'uuid': _uuid.v4(), 'data': payload},
  );
  final id = result.first.first;
  return Response(201, body: jsonEncode({'id': id, 'supplier': {'id': id}}), headers: {'content-type': 'application/json'});
}

Future<Response> updateSupplier(Request request, Connection conn, int id) async {
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final payload = jsonEncode(body);
  await conn.execute(
    Sql.named('UPDATE suppliers SET data = @data::jsonb, status = COALESCE(@status, status) WHERE id = @id'),
    parameters: {'id': id, 'data': payload, 'status': body['status']},
  );
  return Response.ok(jsonEncode({'id': id}), headers: {'content-type': 'application/json'});
}
