import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../accounting/fy.dart';
import '../accounting/post_purchase.dart';
import '../accounting/voucher_numbering.dart';
import '../http.dart';
import '../json_util.dart';

const _uuid = Uuid();

void registerPurchaseVoucherRoutes(Router router, Connection conn) {
  router.get('/api/purchase-vouchers', (_) => listPurchaseVouchers(conn));
  router.get('/api/purchase-vouchers/<id>', (Request request, String id) async {
    final vid = int.tryParse(id);
    if (vid == null) return jsonError('Invalid purchase voucher id', status: 400);
    return getPurchaseVoucherById(conn, vid);
  });
  router.post('/api/purchase-vouchers', (r) => createPurchaseVoucher(r, conn));
}

Future<Response> listPurchaseVouchers(Connection conn) async {
  final rows = await conn.execute('''
    SELECT id, uuid, status, data::text AS data, voucher_no_display, created_at
    FROM purchase_vouchers
    ORDER BY id DESC
  ''');
  final list = rows
      .map((r) => flattenEnvelopeRow(serializeRow(r.toColumnMap())))
      .toList();
  return jsonOk(serializeRows(list));
}

Future<Response> getPurchaseVoucherById(Connection conn, int id) async {
  final headerRows = await conn.execute(
    Sql.named(
      'SELECT id, uuid, status, data::text AS data, voucher_no_display, created_at '
      'FROM purchase_vouchers WHERE id = @id',
    ),
    parameters: {'id': id},
  );
  if (headerRows.isEmpty) {
    return jsonError('Purchase voucher not found: $id', status: 404);
  }
  final headerMap = headerRows.first.toColumnMap();
  var voucher = flattenEnvelopeRow({
    'id': headerMap['id'],
    'uuid': headerMap['uuid'],
    'status': headerMap['status'],
    'data': headerMap['data'],
    'voucher_no_display': headerMap['voucher_no_display'],
    'created_at': '${headerMap['created_at']}',
  });

  final supplierId = voucher['supplier_id'];
  if (supplierId != null) {
    final supRows = await conn.execute(
      Sql.named('SELECT id, data::text AS data FROM suppliers WHERE id = @id'),
      parameters: {'id': supplierId},
    );
    if (supRows.isNotEmpty) {
      final supMap = supRows.first.toColumnMap();
      final sup = flattenEnvelopeRow({'id': supMap['id'], 'data': supMap['data']});
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
      'SELECT id, voucher_id, data::text AS data FROM purchase_voucher_items '
      'WHERE voucher_id = @id ORDER BY id',
    ),
    parameters: {'id': id},
  );
  final items = itemRows
      .map((r) => flattenEnvelopeRow(serializeRow(r.toColumnMap())))
      .toList();

  return jsonOk({'voucher': voucher, 'items': items});
}

double _num(dynamic v) => (v as num?)?.toDouble() ?? double.tryParse('$v') ?? 0;

Map<String, dynamic> _itemToJson(Map<String, dynamic> it) => {
      'product_id': it['product_id'],
      'description': it['description'],
      'uom': it['uom'],
      'hsn': it['hsn'] ?? it['hsn_code'],
      'quantity': it['quantity'] ?? 0,
      'rate': it['rate'] ?? 0,
      'cgst_percent': it['cgst_percent'] ?? 0,
      'sgst_percent': it['sgst_percent'] ?? 0,
      'igst_percent': it['igst_percent'] ?? 0,
      'taxable': _num(it['taxable'] ?? it['taxable_amount']),
      'cgst': _num(it['cgst'] ?? it['cgst_amount']),
      'sgst': _num(it['sgst'] ?? it['sgst_amount']),
      'igst': _num(it['igst'] ?? it['igst_amount']),
      'total': _num(it['total'] ?? it['compound_total']),
    };

Future<Response> createPurchaseVoucher(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final items = asItemList(body.remove('items'));
  if (items.isEmpty) {
    return jsonError('Purchase voucher must contain at least one item');
  }
  final supplierId = body['supplier_id'];
  if (supplierId == null) return jsonError('supplier_id is required');

  body.remove('voucher_no');

  final taxableTotal = _num(body['taxable_total']);
  final cgstTotal = _num(body['cgst_total']);
  final sgstTotal = _num(body['sgst_total']);
  final igstTotal = _num(body['igst_total']);
  final freight = _num(body['freight'] ?? body['fwd_charge']);
  final grandTotal = _num(body['grand_total']);
  final status = '${body['status'] ?? 'POSTED'}';
  final voucherDate = FinancialYear.parseVoucherDate(
    body['voucher_date'] ?? body['transaction_date'],
  );

  try {
    return await conn.runTx((tx) async {
      final allocated = await allocateVoucherNumber(
        session: tx,
        voucherType: VoucherTypes.purchase,
        voucherDate: voucherDate,
      );

      final headerJson = <String, dynamic>{
        'uuid': body['uuid'] ?? _uuid.v4(),
        'status': status,
        'voucher_no': allocated.sequence,
        'supplier_id': supplierId,
        'voucher_date': '${body['voucher_date'] ?? voucherDate.toIso8601String().split('T').first}',
        'taxable_total': taxableTotal,
        'cgst_total': cgstTotal,
        'sgst_total': sgstTotal,
        'igst_total': igstTotal,
        'grand_total': grandTotal,
        'purchase_order_id': body['purchase_order_id'],
        'supplier_invoice_no': body['supplier_invoice_no'],
        'supplier_invoice_date': body['supplier_invoice_date'],
      };
      if (freight != 0) {
        headerJson['freight'] = freight;
      }

      final result = await tx.execute(
        Sql.named('''
          INSERT INTO purchase_vouchers (uuid, status, data, voucher_no_display, created_at)
          VALUES (
            COALESCE(@uuid::uuid, gen_random_uuid()),
            @status,
            @data::jsonb,
            @voucher_no_display,
            NOW()
          )
          RETURNING id
        '''),
        parameters: {
          'uuid': headerJson['uuid'],
          'status': status,
          'data': jsonEncode(headerJson),
          'voucher_no_display': allocated.display,
        },
      );
      final voucherId = (result.first.first as num).toInt();

      for (final it in items) {
        await tx.execute(
          Sql.named('''
            INSERT INTO purchase_voucher_items (voucher_id, data)
            VALUES (@voucher_id, @data::jsonb)
          '''),
          parameters: {
            'voucher_id': voucherId,
            'data': jsonEncode(_itemToJson(it)),
          },
        );
      }

      await postPurchaseVoucher(
        session: tx,
        purchaseVoucherId: voucherId,
        supplierId: (supplierId as num).toInt(),
        voucherDate: voucherDate,
        voucherNo: allocated.sequence,
        voucherNoDisplay: allocated.display,
        status: status,
        taxableTotal: taxableTotal,
        cgstTotal: cgstTotal,
        sgstTotal: sgstTotal,
        igstTotal: igstTotal,
        freight: freight,
        grandTotal: grandTotal,
        narration: 'Purchase ${allocated.display}',
      );

      return jsonOk({
        'id': voucherId,
        'voucher': {
          'id': voucherId,
          'voucher_no': allocated.sequence,
          'voucher_no_display': allocated.display,
        },
      }, status: 201);
    });
  } catch (e) {
    return jsonError('Purchase voucher save failed: $e', status: 400);
  }
}
