import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../http.dart';

const _uuid = Uuid();

void registerAdjustmentNoteRoutes(Router router, Connection conn) {
  router.get('/api/adjustment-notes', (Request request) => listAdjustmentNotes(request, conn));
  router.post('/api/adjustment-notes', (r) => createAdjustmentNote(r, conn));
  router.get('/api/adjustment-notes/<id>', (Request _, String id) async {
    final nid = int.tryParse(id);
    if (nid == null) return jsonError('Invalid adjustment note id', status: 400);
    return getAdjustmentNoteById(conn, nid);
  });
}

Future<Response> listAdjustmentNotes(Request request, Connection conn) async {
  final noteType = request.url.queryParameters['note_type'];
  final where = noteType == null ? '' : 'WHERE an.note_type = @note_type';
  final rows = await conn.execute(
    Sql.named('''
      SELECT an.*,
        CASE
          WHEN an.party_kind = 'SUPPLIER' THEN (SELECT data::jsonb->>'supplier_name' FROM suppliers WHERE id = an.party_id)
          WHEN an.party_kind = 'CUSTOMER' THEN (SELECT customer_name FROM customers WHERE id = an.party_id)
          ELSE '-'
        END AS party_name
      FROM adjustment_notes an
      $where
      ORDER BY an.issue_date DESC NULLS LAST, an.id DESC
    '''),
    parameters: noteType == null ? {} : {'note_type': noteType},
  );
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}

Future<Response> getAdjustmentNoteById(Connection conn, int id) async {
  final rows = await conn.execute(
    Sql.named('SELECT * FROM adjustment_notes WHERE id = @id'),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonError('Adjustment note not found: $id', status: 404);
  final items = await conn.execute(
    Sql.named('SELECT * FROM adjustment_note_items WHERE note_id = @id ORDER BY id'),
    parameters: {'id': id},
  );
  return jsonOk({
    'note': serializeRow(rows.first.toColumnMap()),
    'items': serializeRows(items.map((r) => r.toColumnMap()).toList()),
  });
}

Future<Response> createAdjustmentNote(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final items = asItemList(body.remove('items'));
  if (items.isEmpty) return jsonError('Adjustment note must contain at least one item');

  return await conn.runTx((tx) async {
    final result = await tx.execute(
      Sql.named('''
        INSERT INTO adjustment_notes (
          uuid, note_type, note_no, note_bill_no, issue_date, original_invoice_ref, original_invoice_date,
          reversal_reason, eway_bill, logistics, party_kind, party_id, address, city, pincode, gstin,
          narration, taxable_total, tax_total, grand_total, created_at
        ) VALUES (
          @uuid, @note_type, @note_no, @note_bill_no, @issue_date, @original_invoice_ref, @original_invoice_date,
          @reversal_reason, @eway_bill, @logistics, @party_kind, @party_id, @address, @city, @pincode, @gstin,
          @narration, @taxable_total, @tax_total, @grand_total, COALESCE(@created_at::timestamptz, NOW())
        ) RETURNING id
      '''),
      parameters: {
        'uuid': body['uuid'] ?? _uuid.v4(),
        'note_type': body['note_type'],
        'note_no': body['note_no'],
        'note_bill_no': body['note_bill_no'],
        'issue_date': body['issue_date'],
        'original_invoice_ref': body['original_invoice_ref'],
        'original_invoice_date': body['original_invoice_date'],
        'reversal_reason': body['reversal_reason'],
        'eway_bill': body['eway_bill'],
        'logistics': body['logistics'],
        'party_kind': body['party_kind'],
        'party_id': body['party_id'],
        'address': body['address'],
        'city': body['city'],
        'pincode': body['pincode'],
        'gstin': body['gstin'],
        'narration': body['narration'],
        'taxable_total': body['taxable_total'] ?? 0,
        'tax_total': body['tax_total'] ?? 0,
        'grand_total': body['grand_total'] ?? 0,
        'created_at': body['created_at'],
      },
    );
    final noteId = result.first.first as int;
    for (final it in items) {
      await tx.execute(
        Sql.named('''
          INSERT INTO adjustment_note_items (
            note_id, product_id, description, uom, hsn, quantity, rate,
            cgst_percent, sgst_percent, igst_percent, extended_value
          ) VALUES (
            @note_id, @product_id, @description, @uom, @hsn, @quantity, @rate,
            @cgst_percent, @sgst_percent, @igst_percent, @extended_value
          )
        '''),
        parameters: {...it, 'note_id': noteId},
      );
    }
    return jsonOk({'id': noteId, 'note': {'id': noteId}}, status: 201);
  });
}
