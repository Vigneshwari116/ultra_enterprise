import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../http.dart';

const _uuid = Uuid();

void registerQuotationRoutes(Router router, Connection conn) {
  router.get('/api/quotations', (_) => listQuotations(conn));
  router.post('/api/quotations', (r) => createQuotation(r, conn));
  router.get('/api/quotations/<id>', (Request _, String id) async {
    final qid = int.tryParse(id);
    if (qid == null) return jsonError('Invalid quotation id', status: 400);
    return getQuotationById(conn, qid);
  });
  router.put('/api/quotations/<id>/status', (Request r, String id) async {
    final qid = int.tryParse(id);
    if (qid == null) return jsonError('Invalid quotation id', status: 400);
    return updateQuotationStatus(r, conn, qid);
  });
}

Future<Response> listQuotations(Connection conn) async {
  final rows = await conn.execute('''
    SELECT q.*,
      CASE
        WHEN q.party_kind = 'SUPPLIER' THEN (SELECT data::jsonb->>'supplier_name' FROM suppliers WHERE id = q.party_id)
        WHEN q.party_kind = 'CUSTOMER' THEN (SELECT customer_name FROM customers WHERE id = q.party_id)
        ELSE '-'
      END AS party_name,
      (SELECT COALESCE(SUM(quantity), 0) FROM quotation_items WHERE quotation_id = q.id) AS total_qty
    FROM quotations q
    ORDER BY q.quotation_date DESC NULLS LAST, q.id DESC
  ''');
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}

Future<Response> getQuotationById(Connection conn, int id) async {
  final rows = await conn.execute(
    Sql.named('SELECT * FROM quotations WHERE id = @id'),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonError('Quotation not found: $id', status: 404);
  final items = await conn.execute(
    Sql.named('SELECT * FROM quotation_items WHERE quotation_id = @id ORDER BY id'),
    parameters: {'id': id},
  );
  final terms = await conn.execute(
    Sql.named('SELECT * FROM quotation_terms WHERE quotation_id = @id ORDER BY sort_order, id'),
    parameters: {'id': id},
  );
  return jsonOk({
    'quotation': serializeRow(rows.first.toColumnMap()),
    'items': serializeRows(items.map((r) => r.toColumnMap()).toList()),
    'terms': serializeRows(terms.map((r) => r.toColumnMap()).toList()),
  });
}

Future<Response> createQuotation(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final items = asItemList(body.remove('items'));
  final terms = asItemList(body.remove('terms'));
  if (items.isEmpty) return jsonError('Quotation must contain at least one item');

  return await conn.runTx((tx) async {
    final result = await tx.execute(
      Sql.named('''
        INSERT INTO quotations (
          uuid, ref_no, serial_no, quotation_date, validity_days, reference_name, reference_date,
          party_kind, party_id, address, city, pincode, gstin, salutation, subject, body_text,
          freight, net_total, total_qty, status, created_at
        ) VALUES (
          @uuid, @ref_no, @serial_no, @quotation_date, @validity_days, @reference_name, @reference_date,
          @party_kind, @party_id, @address, @city, @pincode, @gstin, @salutation, @subject, @body_text,
          @freight, @net_total, @total_qty, @status, NOW()
        ) RETURNING id
      '''),
      parameters: {
        'uuid': body['uuid'] ?? _uuid.v4(),
        'ref_no': body['ref_no'],
        'serial_no': body['serial_no'],
        'quotation_date': body['quotation_date'],
        'validity_days': body['validity_days'] ?? 0,
        'reference_name': body['reference_name'],
        'reference_date': body['reference_date'],
        'party_kind': body['party_kind'],
        'party_id': body['party_id'],
        'address': body['address'],
        'city': body['city'],
        'pincode': body['pincode'],
        'gstin': body['gstin'],
        'salutation': body['salutation'],
        'subject': body['subject'],
        'body_text': body['body_text'],
        'freight': body['freight'] ?? 0,
        'net_total': body['net_total'] ?? 0,
        'total_qty': body['total_qty'] ?? 0,
        'status': body['status'] ?? 'PENDING',
      },
    );
    final qid = result.first.first as int;
    for (final it in items) {
      await tx.execute(
        Sql.named('''
          INSERT INTO quotation_items (quotation_id, product_id, description, uom, quantity, rate, line_total)
          VALUES (@quotation_id, @product_id, @description, @uom, @quantity, @rate, @line_total)
        '''),
        parameters: {...it, 'quotation_id': qid},
      );
    }
    var sort = 0;
    for (final t in terms) {
      await tx.execute(
        Sql.named('''
          INSERT INTO quotation_terms (quotation_id, sort_order, text)
          VALUES (@quotation_id, @sort_order, @text)
        '''),
        parameters: {
          'quotation_id': qid,
          'sort_order': t['sort_order'] ?? sort++,
          'text': t['text'],
        },
      );
    }
    return jsonOk({'id': qid, 'quotation': {'id': qid}}, status: 201);
  });
}

Future<Response> updateQuotationStatus(Request request, Connection conn, int id) async {
  final body = await readJsonObject(request);
  final status = body['status'];
  if (status == null) return jsonError('status is required');
  final updated = await conn.execute(
    Sql.named('UPDATE quotations SET status = @status WHERE id = @id RETURNING id'),
    parameters: {'id': id, 'status': status},
  );
  if (updated.isEmpty) return jsonError('Quotation not found: $id', status: 404);
  return jsonOk({'id': id, 'status': status});
}
