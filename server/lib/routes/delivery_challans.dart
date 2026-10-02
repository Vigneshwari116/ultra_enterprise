import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../http.dart';

const _uuid = Uuid();

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
      SELECT dc.*,
        CASE
          WHEN dc.party_kind = 'SUPPLIER' THEN (SELECT data::jsonb->>'supplier_name' FROM suppliers WHERE id = dc.party_id)
          WHEN dc.party_kind = 'CUSTOMER' THEN (SELECT customer_name FROM customers WHERE id = dc.party_id)
          ELSE '-'
        END AS party_name
      FROM delivery_challans dc
      $where
      ORDER BY dc.document_date DESC NULLS LAST, dc.id DESC
    '''),
    parameters: dcType == null ? {} : {'dc_type': dcType},
  );
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}

Future<Response> getDeliveryChallanById(Connection conn, int id) async {
  final rows = await conn.execute(
    Sql.named('''
      SELECT dc.*,
        CASE
          WHEN dc.party_kind = 'SUPPLIER' THEN (SELECT data::jsonb->>'supplier_name' FROM suppliers WHERE id = dc.party_id)
          WHEN dc.party_kind = 'CUSTOMER' THEN (SELECT customer_name FROM customers WHERE id = dc.party_id)
          ELSE '-'
        END AS party_name
      FROM delivery_challans dc WHERE dc.id = @id
    '''),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonError('Delivery challan not found: $id', status: 404);
  final items = await conn.execute(
    Sql.named('SELECT * FROM delivery_challan_items WHERE challan_id = @id ORDER BY id'),
    parameters: {'id': id},
  );
  return jsonOk({
    'challan': serializeRow(rows.first.toColumnMap()),
    'items': serializeRows(items.map((r) => r.toColumnMap()).toList()),
  });
}

Future<Response> createDeliveryChallan(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final items = asItemList(body.remove('items'));
  if (items.isEmpty) return jsonError('Delivery challan must contain at least one item');

  return await conn.runTx((tx) async {
    final result = await tx.execute(
      Sql.named('''
        INSERT INTO delivery_challans (
          uuid, dc_type, serial_no, doc_id, document_date, po_ref_no, po_ref_date, total_packages,
          vehicle_dispatch, credit_due_days, eway_bill_no, validity_days, party_kind, party_id,
          billing_address, city, pincode, gstin, account_ref, delivery_site_address,
          fwd_charge, base_value, tax_total, grand_total, total_pcs, status, created_at
        ) VALUES (
          @uuid, @dc_type, @serial_no, @doc_id, @document_date, @po_ref_no, @po_ref_date, @total_packages,
          @vehicle_dispatch, @credit_due_days, @eway_bill_no, @validity_days, @party_kind, @party_id,
          @billing_address, @city, @pincode, @gstin, @account_ref, @delivery_site_address,
          @fwd_charge, @base_value, @tax_total, @grand_total, @total_pcs, @status, NOW()
        ) RETURNING id
      '''),
      parameters: {
        'uuid': body['uuid'] ?? _uuid.v4(),
        'dc_type': body['dc_type'],
        'serial_no': body['serial_no'],
        'doc_id': body['doc_id'],
        'document_date': body['document_date'],
        'po_ref_no': body['po_ref_no'],
        'po_ref_date': body['po_ref_date'],
        'total_packages': body['total_packages'] ?? 0,
        'vehicle_dispatch': body['vehicle_dispatch'],
        'credit_due_days': body['credit_due_days'] ?? 0,
        'eway_bill_no': body['eway_bill_no'],
        'validity_days': body['validity_days'] ?? 0,
        'party_kind': body['party_kind'],
        'party_id': body['party_id'],
        'billing_address': body['billing_address'],
        'city': body['city'],
        'pincode': body['pincode'],
        'gstin': body['gstin'],
        'account_ref': body['account_ref'],
        'delivery_site_address': body['delivery_site_address'],
        'fwd_charge': body['fwd_charge'] ?? 0,
        'base_value': body['base_value'] ?? 0,
        'tax_total': body['tax_total'] ?? 0,
        'grand_total': body['grand_total'] ?? 0,
        'total_pcs': body['total_pcs'] ?? 0,
        'status': body['status'] ?? 'POSTED',
      },
    );
    final challanId = result.first.first as int;
    for (final it in items) {
      await tx.execute(
        Sql.named('''
          INSERT INTO delivery_challan_items (
            challan_id, product_id, description, uom, hsn, quantity, rate,
            cgst_percent, sgst_percent, igst_percent, extended_value, remarks
          ) VALUES (
            @challan_id, @product_id, @description, @uom, @hsn, @quantity, @rate,
            @cgst_percent, @sgst_percent, @igst_percent, @extended_value, @remarks
          )
        '''),
        parameters: {...it, 'challan_id': challanId},
      );
    }
    return jsonOk({'id': challanId, 'challan': {'id': challanId}}, status: 201);
  });
}
