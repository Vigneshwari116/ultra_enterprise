import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../accounting/fy.dart';
import '../accounting/journal_writer.dart';
import '../accounting/post_sales.dart';
import '../accounting/voucher_numbering.dart';
import '../http.dart';

const _uuid = Uuid();

void registerSalesInvoiceRoutes(Router router, Connection conn) {
  router.get('/api/sales-invoices', (_) => listSalesInvoices(conn));
  router.get('/api/sales-invoices/<id>', (Request _, String id) async {
    final iid = int.tryParse(id);
    if (iid == null) return jsonError('Invalid sales invoice id', status: 400);
    return getSalesInvoiceById(conn, iid);
  });
  router.post('/api/sales-invoices', (r) => createSalesInvoice(r, conn));
  router.put('/api/sales-invoices/<id>', (Request r, String id) async {
    final iid = int.tryParse(id);
    if (iid == null) return jsonError('Invalid sales invoice id', status: 400);
    return updateSalesInvoice(r, conn, iid);
  });
  router.delete('/api/sales-invoices/<id>', (Request _, String id) async {
    final iid = int.tryParse(id);
    if (iid == null) return jsonError('Invalid sales invoice id', status: 400);
    return deleteSalesInvoice(conn, iid);
  });
}

Future<Response> listSalesInvoices(Connection conn) async {
  final rows = await conn.execute('''
    SELECT si.*, c.customer_name,
      sz.name AS state_zone_name
    FROM sales_invoices si
    LEFT JOIN customers c ON c.id = si.customer_id
    LEFT JOIN state_zones sz ON sz.id = si.state_zone_id
    ORDER BY si.transaction_date DESC NULLS LAST, si.id DESC
  ''');
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}

Future<Response> getSalesInvoiceById(Connection conn, int id) async {
  final headerRows = await conn.execute(
    Sql.named('''
      SELECT si.*, c.customer_name
      FROM sales_invoices si
      LEFT JOIN customers c ON c.id = si.customer_id
      WHERE si.id = @id
    '''),
    parameters: {'id': id},
  );
  if (headerRows.isEmpty) {
    return jsonError('Sales invoice not found: $id', status: 404);
  }
  final invoice = serializeRow(headerRows.first.toColumnMap());
  final itemRows = await conn.execute(
    Sql.named('''
      SELECT sii.*, p.product_name, u.name AS unit_name
      FROM sales_invoice_items sii
      LEFT JOIN products p ON p.id = sii.product_id
      LEFT JOIN units u ON u.id = sii.unit_id
      WHERE sii.invoice_id = @id
      ORDER BY sii.id
    '''),
    parameters: {'id': id},
  );
  final items = serializeRows(itemRows.map((r) => r.toColumnMap()).toList());
  return jsonOk({'invoice': invoice, 'items': items});
}

double _num(dynamic v) => (v as num?)?.toDouble() ?? double.tryParse('$v') ?? 0;

Future<void> _insertSalesInvoiceItems(
  Session tx,
  int invoiceId,
  List<Map<String, dynamic>> items,
) async {
  for (final it in items) {
    final productId = it['product_id'];
    int? unitId;
    if (productId != null) {
      final urows = await tx.execute(
        Sql.named('SELECT unit_id FROM products WHERE id = @id'),
        parameters: {'id': productId},
      );
      if (urows.isNotEmpty) unitId = (urows.first.first as num?)?.toInt();
    }
    final taxable = _num(it['taxable'] ?? it['taxable_amount']);
    final cgst = _num(it['cgst'] ?? it['cgst_amount']);
    final sgst = _num(it['sgst'] ?? it['sgst_amount']);
    final igst = _num(it['igst'] ?? it['igst_amount']);
    final lineTotal = _num(it['total'] ?? it['compound_total']);
    await tx.execute(
      Sql.named('''
        INSERT INTO sales_invoice_items (
          uuid, invoice_id, product_id, unit_id, description, hsn_code,
          quantity, rate, cgst_percent, sgst_percent, igst_percent,
          taxable_amount, cgst_amount, sgst_amount, igst_amount, compound_total,
          created_at
        ) VALUES (
          @uuid, @invoice_id, @product_id, @unit_id, @description, @hsn_code,
          @quantity, @rate, @cgst_percent, @sgst_percent, @igst_percent,
          @taxable_amount, @cgst_amount, @sgst_amount, @igst_amount, @compound_total,
          NOW()
        )
      '''),
      parameters: {
        'uuid': _uuid.v4(),
        'invoice_id': invoiceId,
        'product_id': productId,
        'unit_id': unitId,
        'description': it['description'],
        'hsn_code': it['hsn'] ?? it['hsn_code'],
        'quantity': it['quantity'] ?? 0,
        'rate': it['rate'] ?? 0,
        'cgst_percent': it['cgst_percent'] ?? 0,
        'sgst_percent': it['sgst_percent'] ?? 0,
        'igst_percent': it['igst_percent'] ?? 0,
        'taxable_amount': taxable,
        'cgst_amount': cgst,
        'sgst_amount': sgst,
        'igst_amount': igst,
        'compound_total': lineTotal,
      },
    );
  }
}

Future<Response> createSalesInvoice(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final items = asItemList(body.remove('items'));
  if (items.isEmpty) return jsonError('Sales invoice must contain at least one item');
  final customerId = body['customer_id'];
  if (customerId == null) return jsonError('customer_id is required');

  // Server owns numbering — ignore client-supplied invoice_no.
  body.remove('invoice_no');

  final taxableTotal = _num(body['taxable_total']);
  final cgstTotal = _num(body['cgst_total']);
  final sgstTotal = _num(body['sgst_total']);
  final igstTotal = _num(body['igst_total']);
  final fwdCharge = _num(body['fwd_charge']);
  final grandTotal = _num(body['grand_total']);
  final compoundGst = cgstTotal + sgstTotal + igstTotal;
  final voucherDate = FinancialYear.parseVoucherDate(body['transaction_date']);

  try {
    return await conn.runTx((tx) async {
    final allocated = await allocateVoucherNumber(
      session: tx,
      voucherType: VoucherTypes.sales,
      voucherDate: voucherDate,
    );

    final result = await tx.execute(
      Sql.named('''
        INSERT INTO sales_invoices (
          uuid, invoice_no, voucher_no_display, customer_id, transaction_date,
          po_no, po_date, state_zone_id, challan_dc_no, challan_dc_date,
          total_packages, vehicle_dispatch_mode, due_days, eway_bill_no,
          bill_type, sel_dc_no, sel_dc_date,
          taxable_total, cgst_total, sgst_total, igst_total, compound_gst_total,
          fwd_charge, grand_total, status, created_at, updated_at
        ) VALUES (
          @uuid, @invoice_no, @voucher_no_display, @customer_id, @transaction_date,
          @po_no, @po_date, @state_zone_id, @challan_dc_no, @challan_dc_date,
          @total_packages, @vehicle_dispatch_mode, @due_days, @eway_bill_no,
          @bill_type, @sel_dc_no, @sel_dc_date,
          @taxable_total, @cgst_total, @sgst_total, @igst_total, @compound_gst_total,
          @fwd_charge, @grand_total, @status, NOW(), NOW()
        ) RETURNING id
      '''),
      parameters: {
        'uuid': body['uuid'] ?? _uuid.v4(),
        'invoice_no': allocated.sequence,
        'voucher_no_display': allocated.display,
        'customer_id': customerId,
        'transaction_date': body['transaction_date'],
        'po_no': body['po_no'],
        'po_date': body['po_date'],
        'state_zone_id': body['state_zone_id'],
        'challan_dc_no': body['challan_dc_no'] ?? body['challan_no'],
        'challan_dc_date': body['challan_dc_date'] ?? body['challan_date'],
        'total_packages': body['total_packages'] ?? 0,
        'vehicle_dispatch_mode': body['vehicle_dispatch_mode'],
        'due_days': body['due_days'] ?? 0,
        'eway_bill_no': body['eway_bill_no'],
        'bill_type': body['bill_type'] ?? 'NORMAL',
        'sel_dc_no': body['sel_dc_no'],
        'sel_dc_date': body['sel_dc_date'],
        'taxable_total': taxableTotal,
        'cgst_total': cgstTotal,
        'sgst_total': sgstTotal,
        'igst_total': igstTotal,
        'compound_gst_total': compoundGst,
        'fwd_charge': fwdCharge,
        'grand_total': grandTotal,
        'status': body['status'] ?? 'POSTED',
      },
    );
    final invoiceId = (result.first.first as num).toInt();

    await _insertSalesInvoiceItems(tx, invoiceId, items);

    await postSalesInvoice(
      session: tx,
      salesInvoiceId: invoiceId,
      customerId: (customerId as num).toInt(),
      voucherDate: voucherDate,
      voucherNo: allocated.sequence,
      voucherNoDisplay: allocated.display,
      taxableTotal: taxableTotal,
      cgstTotal: cgstTotal,
      sgstTotal: sgstTotal,
      igstTotal: igstTotal,
      fwdCharge: fwdCharge,
      grandTotal: grandTotal,
      narration: 'Sales ${allocated.display}',
    );

    return jsonOk({
      'id': invoiceId,
      'invoice': {
        'id': invoiceId,
        'invoice_no': allocated.sequence,
        'voucher_no_display': allocated.display,
      },
    }, status: 201);
    });
  } catch (e) {
    return jsonError('Sales invoice save failed: $e', status: 400);
  }
}

Future<Response> updateSalesInvoice(
  Request request,
  Connection conn,
  int id,
) async {
  final body = await readJsonObject(request);
  final items = asItemList(body.remove('items'));
  if (items.isEmpty) return jsonError('Sales invoice must contain at least one item');
  final customerId = body['customer_id'];
  if (customerId == null) return jsonError('customer_id is required');

  body.remove('invoice_no');
  body.remove('voucher_no_display');

  final taxableTotal = _num(body['taxable_total']);
  final cgstTotal = _num(body['cgst_total']);
  final sgstTotal = _num(body['sgst_total']);
  final igstTotal = _num(body['igst_total']);
  final fwdCharge = _num(body['fwd_charge']);
  final grandTotal = _num(body['grand_total']);
  final compoundGst = cgstTotal + sgstTotal + igstTotal;
  final voucherDate = FinancialYear.parseVoucherDate(body['transaction_date']);

  try {
    return await conn.runTx((tx) async {
      final existing = await tx.execute(
        Sql.named('''
          SELECT invoice_no, voucher_no_display
          FROM sales_invoices WHERE id = @id
        '''),
        parameters: {'id': id},
      );
      if (existing.isEmpty) {
        return jsonError('Sales invoice not found: $id', status: 404);
      }
      final row = existing.first.toColumnMap();
      final voucherNo = (row['invoice_no'] as num).toInt();
      final voucherNoDisplay = '${row['voucher_no_display']}';

      await tx.execute(
        Sql.named('''
          UPDATE sales_invoices SET
            customer_id = @customer_id,
            transaction_date = @transaction_date,
            po_no = @po_no,
            po_date = @po_date,
            state_zone_id = @state_zone_id,
            challan_dc_no = @challan_dc_no,
            challan_dc_date = @challan_dc_date,
            total_packages = @total_packages,
            vehicle_dispatch_mode = @vehicle_dispatch_mode,
            due_days = @due_days,
            eway_bill_no = @eway_bill_no,
            bill_type = @bill_type,
            sel_dc_no = @sel_dc_no,
            sel_dc_date = @sel_dc_date,
            taxable_total = @taxable_total,
            cgst_total = @cgst_total,
            sgst_total = @sgst_total,
            igst_total = @igst_total,
            compound_gst_total = @compound_gst_total,
            fwd_charge = @fwd_charge,
            grand_total = @grand_total,
            status = @status,
            updated_at = NOW()
          WHERE id = @id
        '''),
        parameters: {
          'id': id,
          'customer_id': customerId,
          'transaction_date': body['transaction_date'],
          'po_no': body['po_no'],
          'po_date': body['po_date'],
          'state_zone_id': body['state_zone_id'],
          'challan_dc_no': body['challan_dc_no'] ?? body['challan_no'],
          'challan_dc_date': body['challan_dc_date'] ?? body['challan_date'],
          'total_packages': body['total_packages'] ?? 0,
          'vehicle_dispatch_mode': body['vehicle_dispatch_mode'],
          'due_days': body['due_days'] ?? 0,
          'eway_bill_no': body['eway_bill_no'],
          'bill_type': body['bill_type'] ?? 'NORMAL',
          'sel_dc_no': body['sel_dc_no'],
          'sel_dc_date': body['sel_dc_date'],
          'taxable_total': taxableTotal,
          'cgst_total': cgstTotal,
          'sgst_total': sgstTotal,
          'igst_total': igstTotal,
          'compound_gst_total': compoundGst,
          'fwd_charge': fwdCharge,
          'grand_total': grandTotal,
          'status': body['status'] ?? 'POSTED',
        },
      );

      await tx.execute(
        Sql.named('DELETE FROM sales_invoice_items WHERE invoice_id = @id'),
        parameters: {'id': id},
      );
      await _insertSalesInvoiceItems(tx, id, items);

      await deleteJournalForVoucher(
        tx,
        voucherType: VoucherTypes.sales,
        voucherNo: voucherNo,
      );
      await postSalesInvoice(
        session: tx,
        salesInvoiceId: id,
        customerId: (customerId as num).toInt(),
        voucherDate: voucherDate,
        voucherNo: voucherNo,
        voucherNoDisplay: voucherNoDisplay,
        taxableTotal: taxableTotal,
        cgstTotal: cgstTotal,
        sgstTotal: sgstTotal,
        igstTotal: igstTotal,
        fwdCharge: fwdCharge,
        grandTotal: grandTotal,
        narration: 'Sales $voucherNoDisplay',
      );

      return jsonOk({
        'id': id,
        'invoice': {
          'id': id,
          'invoice_no': voucherNo,
          'voucher_no_display': voucherNoDisplay,
        },
      });
    });
  } catch (e) {
    return jsonError('Sales invoice save failed: $e', status: 400);
  }
}

Future<Response> deleteSalesInvoice(Connection conn, int id) async {
  try {
    return await conn.runTx((tx) async {
      final existing = await tx.execute(
        Sql.named('SELECT invoice_no FROM sales_invoices WHERE id = @id'),
        parameters: {'id': id},
      );
      if (existing.isEmpty) {
        return jsonError('Sales invoice not found: $id', status: 404);
      }
      final voucherNo = (existing.first.first as num).toInt();

      await deleteJournalForVoucher(
        tx,
        voucherType: VoucherTypes.sales,
        voucherNo: voucherNo,
      );
      final deleted = await tx.execute(
        Sql.named('DELETE FROM sales_invoices WHERE id = @id RETURNING id'),
        parameters: {'id': id},
      );
      if (deleted.isEmpty) {
        return jsonError('Sales invoice not found: $id', status: 404);
      }
      return jsonOk({'id': id, 'deleted': true});
    });
  } catch (e) {
    return jsonError('Sales invoice delete failed: $e', status: 400);
  }
}
