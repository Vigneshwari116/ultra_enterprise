import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../http.dart';
import '../json_util.dart';

const _uuid = Uuid();

void registerCashTransactionRoutes(Router router, Connection conn) {
  router.get('/api/receipts', (_) => listReceipts(conn));
  router.post('/api/receipts', (r) => createReceipt(r, conn));
  router.get('/api/payments', (_) => listPayments(conn));
  router.post('/api/payments', (r) => createPayment(r, conn));
  router.get('/api/cash-passbook', (_) => cashPassbook(conn));
}

Future<Response> listReceipts(Connection conn) async {
  final rows = await conn.execute('''
    SELECT id, uuid, kind, data, voucher_no_display, created_at
    FROM receipts
    ORDER BY created_at DESC NULLS LAST, id DESC
  ''');
  final list = rows
      .map((r) => flattenEnvelopeRow(serializeRow(r.toColumnMap())))
      .toList();
  return jsonOk(serializeRows(list));
}

Future<Response> createReceipt(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final amount = (body['amount'] as num?)?.toDouble() ?? 0;
  if (amount <= 0) return jsonError('amount must be greater than zero');
  if (body['customer_id'] == null) return jsonError('customer_id is required');

  final payload = jsonEncode({
    'customer_id': body['customer_id'],
    'receipt_date': body['receipt_date'],
    'amount': amount,
    'narration': body['narration'],
    'created_at': body['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
  });

  final result = await conn.execute(
    Sql.named('''
      INSERT INTO receipts (uuid, kind, data, created_at)
      VALUES (@uuid, 'RECEIPT', @data, COALESCE(@created_at::timestamptz, NOW()))
      RETURNING id
    '''),
    parameters: {
      'uuid': _uuid.v4(),
      'data': payload,
      'created_at': body['created_at'],
    },
  );
  final id = result.first.first;
  return jsonOk({'id': id}, status: 201);
}

Future<Response> listPayments(Connection conn) async {
  final rows = await conn.execute('''
    SELECT id, uuid, kind, data, voucher_no_display, created_at
    FROM payments
    ORDER BY created_at DESC NULLS LAST, id DESC
  ''');
  final list = rows
      .map((r) => flattenEnvelopeRow(serializeRow(r.toColumnMap())))
      .toList();
  return jsonOk(serializeRows(list));
}

Future<Response> createPayment(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final amount = (body['amount'] as num?)?.toDouble() ?? 0;
  if (amount <= 0) return jsonError('amount must be greater than zero');
  if (body['supplier_id'] == null) return jsonError('supplier_id is required');

  final payload = jsonEncode({
    'supplier_id': body['supplier_id'],
    'payment_date': body['payment_date'],
    'amount': amount,
    'payment_mode': body['payment_mode'] ?? 'CASH',
    'reference_no': body['reference_no'] ?? '',
    'narration': body['narration'],
    'created_at': body['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
  });

  final result = await conn.execute(
    Sql.named('''
      INSERT INTO payments (uuid, kind, data, created_at)
      VALUES (@uuid, 'PAYMENT', @data, COALESCE(@created_at::timestamptz, NOW()))
      RETURNING id
    '''),
    parameters: {
      'uuid': _uuid.v4(),
      'data': payload,
      'created_at': body['created_at'],
    },
  );
  final id = result.first.first;
  return jsonOk({'id': id}, status: 201);
}

Future<Response> cashPassbook(Connection conn) async {
  final rows = await conn.execute('''
    SELECT 'CR' AS side, r.id AS entry_id,
      (r.data::jsonb->>'receipt_date')::date AS entry_date,
      (r.data::jsonb->>'amount')::numeric AS amount,
      r.data::jsonb->>'narration' AS narration,
      c.customer_name AS party_name,
      'CUSTOMER' AS party_kind
    FROM receipts r
    LEFT JOIN customers c ON c.id = (r.data::jsonb->>'customer_id')::int
    UNION ALL
    SELECT 'DR' AS side, p.id AS entry_id,
      (p.data::jsonb->>'payment_date')::date AS entry_date,
      (p.data::jsonb->>'amount')::numeric AS amount,
      p.data::jsonb->>'narration' AS narration,
      s.data::jsonb->>'supplier_name' AS party_name,
      'SUPPLIER' AS party_kind
    FROM payments p
    LEFT JOIN suppliers s ON s.id = (p.data::jsonb->>'supplier_id')::int
    ORDER BY entry_date DESC NULLS LAST, entry_id DESC
  ''');
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}
