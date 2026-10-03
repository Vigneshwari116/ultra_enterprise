import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../http.dart';
import '../json_util.dart';
import '../sql_supplier.dart';

const _uuid = Uuid();

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
  final where = status == 'open' ? "WHERE po.status != 'RECEIVED'" : '';
  final rows = await conn.execute('''
    SELECT po.*, $supplierPartyNameExpr AS party_name,
      (SELECT COALESCE(SUM(poi.quantity), 0) FROM purchase_order_items poi WHERE poi.purchase_order_id = po.id) AS total_qty
    FROM purchase_orders po
    $supplierJoin
    $where
    ORDER BY po.po_date DESC NULLS LAST, po.id DESC
  ''');
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}

Future<Response> getPurchaseOrderById(Connection conn, int id) async {
  final rows = await conn.execute(
    Sql.named('''
      SELECT po.*,
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
      LEFT JOIN suppliers s ON s.id = po.supplier_id
      WHERE po.id = @id
    '''),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonError('Purchase order not found: $id', status: 404);
  final items = await conn.execute(
    Sql.named('SELECT * FROM purchase_order_items WHERE purchase_order_id = @id ORDER BY id'),
    parameters: {'id': id},
  );
  return jsonOk({
    'order': serializeRow(flattenEnvelopeRow(rows.first.toColumnMap())),
    'items': serializeRows(items.map((r) => r.toColumnMap()).toList()),
  });
}

Future<Response> createPurchaseOrder(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final items = asItemList(body.remove('items'));
  if (items.isEmpty) return jsonError('Purchase order must contain at least one item');

  return await conn.runTx((tx) async {
    final result = await tx.execute(
      Sql.named('''
        INSERT INTO purchase_orders (
          uuid, po_bill_no, po_no, po_date, delivery_due_date, supplier_ref_no, total_packages,
          delivery_mode, remarks, supplier_id, state_zone, due_days, estimated_freight,
          taxable_total, cgst_total, sgst_total, igst_total, grand_total, status
        ) VALUES (
          @uuid, @po_bill_no, @po_no, @po_date, @delivery_due_date, @supplier_ref_no, @total_packages,
          @delivery_mode, @remarks, @supplier_id, @state_zone, @due_days, @estimated_freight,
          @taxable_total, @cgst_total, @sgst_total, @igst_total, @grand_total, @status
        ) RETURNING id
      '''),
      parameters: {
        'uuid': body['uuid'] ?? _uuid.v4(),
        'po_bill_no': body['po_bill_no'],
        'po_no': body['po_no'],
        'po_date': body['po_date'],
        'delivery_due_date': body['delivery_due_date'],
        'supplier_ref_no': body['supplier_ref_no'],
        'total_packages': body['total_packages'] ?? 0,
        'delivery_mode': body['delivery_mode'],
        'remarks': body['remarks'],
        'supplier_id': body['supplier_id'],
        'state_zone': body['state_zone'],
        'due_days': body['due_days'] ?? 0,
        'estimated_freight': body['estimated_freight'] ?? 0,
        'taxable_total': body['taxable_total'] ?? 0,
        'cgst_total': body['cgst_total'] ?? 0,
        'sgst_total': body['sgst_total'] ?? 0,
        'igst_total': body['igst_total'] ?? 0,
        'grand_total': body['grand_total'] ?? 0,
        'status': body['status'] ?? 'PENDING',
      },
    );
    final orderId = result.first.first as int;
    for (final it in items) {
      await tx.execute(
        Sql.named('''
          INSERT INTO purchase_order_items (
            purchase_order_id, product_id, description, uom, hsn, quantity, rate,
            cgst_percent, sgst_percent, igst_percent, taxable, cgst, sgst, igst, total
          ) VALUES (
            @purchase_order_id, @product_id, @description, @uom, @hsn, @quantity, @rate,
            @cgst_percent, @sgst_percent, @igst_percent, @taxable, @cgst, @sgst, @igst, @total
          )
        '''),
        parameters: {...it, 'purchase_order_id': orderId},
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
