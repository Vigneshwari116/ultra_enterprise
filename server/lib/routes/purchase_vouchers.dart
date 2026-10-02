import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../json_util.dart';

Future<Response> getPurchaseVoucherById(Connection conn, int id) async {
  final headerRows = await conn.execute(
    Sql.named(
      'SELECT id, uuid, status, data::text AS data, created_at '
      'FROM purchase_vouchers WHERE id = @id',
    ),
    parameters: {'id': id},
  );
  if (headerRows.isEmpty) {
    return Response.notFound(
      jsonEncode({'error': 'Purchase voucher not found: $id'}),
      headers: {'content-type': 'application/json'},
    );
  }
  final headerMap = headerRows.first.toColumnMap();
  var voucher = flattenEnvelopeRow({
    'id': headerMap['id'],
    'uuid': headerMap['uuid'],
    'status': headerMap['status'],
    'data': headerMap['data'],
    'created_at': '${headerMap['created_at']}',
  });

  final supplierId = voucher['supplier_id'];
  if (supplierId != null) {
    final supRows = await conn.execute(
      Sql.named('SELECT id, data::text AS data FROM suppliers WHERE id = @id'),
      parameters: {'id': supplierId},
    );
    if (supRows.isNotEmpty) {
      final sup = flattenEnvelopeRow({
        'id': supRows.first.toColumnMap()['id'],
        'data': supRows.first.toColumnMap()['data'],
      });
      for (final key in [
        'supplier_name',
        'address',
        'city',
        'postal_pincode',
        'gstin',
        'primary_mobile',
        'bank_name',
        'bank_account_no',
        'ifsc_code',
        'branch_address',
      ]) {
        voucher.putIfAbsent(key, () => sup[key]);
      }
    }
  }

  final poId = voucher['purchase_order_id'];
  if (poId != null) {
    final poRows = await conn.execute(
      Sql.named('SELECT po_no, po_date FROM purchase_orders WHERE id = @id'),
      parameters: {'id': poId},
    );
    if (poRows.isNotEmpty) {
      final po = poRows.first.toColumnMap();
      voucher['linked_po_no'] = po['po_no'];
      voucher['linked_po_date'] = '${po['po_date']}';
    }
  }

  final itemRows = await conn.execute(
    Sql.named(
      'SELECT id, voucher_id, product_id, description, uom, hsn, quantity, rate, '
      'cgst_percent, sgst_percent, igst_percent, taxable, cgst, sgst, igst, total '
      'FROM purchase_voucher_items WHERE voucher_id = @id ORDER BY id',
    ),
    parameters: {'id': id},
  );
  final items = itemRows
      .map((r) => r.toColumnMap())
      .map((m) => m.map((k, v) => MapEntry(k, v is DateTime ? v.toIso8601String() : v)))
      .toList();

  return Response.ok(
    jsonEncode({'voucher': voucher, 'items': items}),
    headers: {'content-type': 'application/json'},
  );
}
