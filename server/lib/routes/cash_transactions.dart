import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http.dart';

void registerCashTransactionRoutes(Router router, Connection conn) {
  router.get('/api/receipts', (_) => listReceipts(conn));
  router.post('/api/receipts', (r) => createReceipt(r, conn));
  router.get('/api/payments', (_) => listPayments(conn));
  router.post('/api/payments', (r) => createPayment(r, conn));
  router.get('/api/cash-passbook', (_) => cashPassbook(conn));
}

Future<Response> listReceipts(Connection conn) async {
  final rows = await conn.execute('''
    SELECT * FROM receipts ORDER BY receipt_date DESC NULLS LAST, id DESC
  ''');
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}

Future<Response> createReceipt(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final amount = (body['amount'] as num?)?.toDouble() ?? 0;
  if (amount <= 0) return jsonError('amount must be greater than zero');
  if (body['customer_id'] == null) return jsonError('customer_id is required');
  final result = await conn.execute(
    Sql.named('''
      INSERT INTO receipts (customer_id, receipt_date, amount, narration, created_at)
      VALUES (@customer_id, @receipt_date, @amount, @narration, COALESCE(@created_at::timestamptz, NOW()))
      RETURNING id
    '''),
    parameters: {
      'customer_id': body['customer_id'],
      'receipt_date': body['receipt_date'],
      'amount': amount,
      'narration': body['narration'],
      'created_at': body['created_at'],
    },
  );
  final id = result.first.first;
  return jsonOk({'id': id}, status: 201);
}

Future<Response> listPayments(Connection conn) async {
  final rows = await conn.execute('''
    SELECT * FROM payments ORDER BY payment_date DESC NULLS LAST, id DESC
  ''');
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}

Future<Response> createPayment(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final amount = (body['amount'] as num?)?.toDouble() ?? 0;
  if (amount <= 0) return jsonError('amount must be greater than zero');
  if (body['supplier_id'] == null) return jsonError('supplier_id is required');
  final result = await conn.execute(
    Sql.named('''
      INSERT INTO payments (supplier_id, payment_date, amount, payment_mode, reference_no, narration, created_at)
      VALUES (@supplier_id, @payment_date, @amount, @payment_mode, @reference_no, @narration, COALESCE(@created_at::timestamptz, NOW()))
      RETURNING id
    '''),
    parameters: {
      'supplier_id': body['supplier_id'],
      'payment_date': body['payment_date'],
      'amount': amount,
      'payment_mode': body['payment_mode'] ?? 'CASH',
      'reference_no': body['reference_no'] ?? '',
      'narration': body['narration'],
      'created_at': body['created_at'],
    },
  );
  final id = result.first.first;
  return jsonOk({'id': id}, status: 201);
}

Future<Response> cashPassbook(Connection conn) async {
  final rows = await conn.execute('''
    SELECT 'CR' AS side, r.id AS entry_id, r.receipt_date AS entry_date, r.amount AS amount,
      r.narration AS narration, c.customer_name AS party_name, 'CUSTOMER' AS party_kind
    FROM receipts r
    LEFT JOIN customers c ON c.id = r.customer_id
    UNION ALL
    SELECT 'DR' AS side, p.id AS entry_id, p.payment_date AS entry_date, p.amount AS amount,
      p.narration AS narration, s.data::jsonb->>'supplier_name' AS party_name, 'SUPPLIER' AS party_kind
    FROM payments p
    LEFT JOIN suppliers s ON s.id = p.supplier_id
    ORDER BY entry_date DESC NULLS LAST, entry_id DESC
  ''');
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}
