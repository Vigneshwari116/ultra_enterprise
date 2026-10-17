import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../accounting/fy.dart';
import '../accounting/post_payment.dart';
import '../accounting/post_receipt.dart';
import '../accounting/voucher_numbering.dart';
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

String _normalizeCashBank(Map<String, dynamic> body) {
  final raw = '${body['cash_bank'] ?? body['payment_mode'] ?? 'CASH'}'.toUpperCase();
  if (raw == 'BANK') return 'BANK';
  return 'CASH';
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

  final cashBank = _normalizeCashBank(body);
  final voucherDate = FinancialYear.parseVoucherDate(body['receipt_date']);

  try {
    return await conn.runTx((tx) async {
      final allocated = await allocateVoucherNumber(
        session: tx,
        voucherType: VoucherTypes.receipt,
        voucherDate: voucherDate,
      );

      final headerJson = <String, dynamic>{
        'customer_id': body['customer_id'],
        'receipt_date': body['receipt_date'],
        'amount': amount,
        'narration': body['narration'],
        'cash_bank': cashBank,
        'voucher_no': allocated.sequence,
        'created_at': body['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
      };

      final result = await tx.execute(
        Sql.named('''
          INSERT INTO receipts (uuid, kind, data, voucher_no_display, created_at)
          VALUES (@uuid, 'RECEIPT', @data, @voucher_no_display, COALESCE(@created_at::timestamptz, NOW()))
          RETURNING id
        '''),
        parameters: {
          'uuid': _uuid.v4(),
          'data': jsonEncode(headerJson),
          'voucher_no_display': allocated.display,
          'created_at': body['created_at'],
        },
      );
      final receiptId = (result.first.first as num).toInt();

      await postReceipt(
        session: tx,
        receiptId: receiptId,
        customerId: (body['customer_id'] as num).toInt(),
        voucherDate: voucherDate,
        voucherNo: allocated.sequence,
        voucherNoDisplay: allocated.display,
        amount: amount,
        cashBank: cashBank,
        narration: body['narration']?.toString(),
      );

      return jsonOk({
        'id': receiptId,
        'receipt': {
          'id': receiptId,
          'voucher_no': allocated.sequence,
          'voucher_no_display': allocated.display,
        },
      }, status: 201);
    });
  } catch (e) {
    return jsonError('Receipt save failed: $e', status: 400);
  }
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

  final cashBank = _normalizeCashBank(body);
  final voucherDate = FinancialYear.parseVoucherDate(body['payment_date']);

  try {
    return await conn.runTx((tx) async {
      final allocated = await allocateVoucherNumber(
        session: tx,
        voucherType: VoucherTypes.payment,
        voucherDate: voucherDate,
      );

      final headerJson = <String, dynamic>{
        'supplier_id': body['supplier_id'],
        'payment_date': body['payment_date'],
        'amount': amount,
        'payment_mode': body['payment_mode'] ?? cashBank,
        'reference_no': body['reference_no'] ?? '',
        'narration': body['narration'],
        'cash_bank': cashBank,
        'voucher_no': allocated.sequence,
        'created_at': body['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
      };

      final result = await tx.execute(
        Sql.named('''
          INSERT INTO payments (uuid, kind, data, voucher_no_display, created_at)
          VALUES (@uuid, 'PAYMENT', @data, @voucher_no_display, COALESCE(@created_at::timestamptz, NOW()))
          RETURNING id
        '''),
        parameters: {
          'uuid': _uuid.v4(),
          'data': jsonEncode(headerJson),
          'voucher_no_display': allocated.display,
          'created_at': body['created_at'],
        },
      );
      final paymentId = (result.first.first as num).toInt();

      await postPayment(
        session: tx,
        paymentId: paymentId,
        supplierId: (body['supplier_id'] as num).toInt(),
        voucherDate: voucherDate,
        voucherNo: allocated.sequence,
        voucherNoDisplay: allocated.display,
        amount: amount,
        cashBank: cashBank,
        narration: body['narration']?.toString(),
      );

      return jsonOk({
        'id': paymentId,
        'payment': {
          'id': paymentId,
          'voucher_no': allocated.sequence,
          'voucher_no_display': allocated.display,
        },
      }, status: 201);
    });
  } catch (e) {
    return jsonError('Payment save failed: $e', status: 400);
  }
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
