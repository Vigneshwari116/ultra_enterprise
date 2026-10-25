import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http.dart';

void registerJournalRoutes(Router router, Connection conn) {
  router.post('/api/journal-vouchers', (r) => createJournalVoucher(r, conn));
  router.get('/api/journal-vouchers/summary', (_) => journalSummary(conn));
}

Future<Response> journalSummary(Connection conn) async {
  final rows = await conn.execute('''
    SELECT jv.id AS voucher_id, jv.voucher_date, jv.narration, jv.total_amount,
      jvl.line_no, jvl.dr_account_label, jvl.cr_account_label, jvl.amount
    FROM journal_voucher_lines jvl
    INNER JOIN journal_vouchers jv ON jv.id = jvl.voucher_id
    ORDER BY jv.voucher_date DESC NULLS LAST, jv.id DESC, jvl.line_no ASC
  ''');
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}

Future<Response> createJournalVoucher(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final lines = asItemList(body.remove('lines'));
  if (lines.isEmpty) return jsonError('Journal voucher must contain at least one line');
  final total = (body['total_amount'] as num?)?.toDouble() ??
      lines.fold<double>(0, (s, l) => s + ((l['amount'] as num?)?.toDouble() ?? 0));

  return await conn.runTx((tx) async {
    final result = await tx.execute(
      Sql.named('''
        INSERT INTO journal_vouchers (voucher_date, narration, total_amount, created_at)
        VALUES (@voucher_date, @narration, @total_amount, NOW())
        RETURNING id
      '''),
      parameters: {
        'voucher_date': body['voucher_date'],
        'narration': body['narration'],
        'total_amount': total,
      },
    );
    final vid = result.first.first as int;
    var lineNo = 1;
    for (final line in lines) {
      await tx.execute(
        Sql.named('''
          INSERT INTO journal_voucher_lines (
            voucher_id, line_no, dr_account_key, dr_account_label, cr_account_key, cr_account_label, amount
          ) VALUES (
            @voucher_id, @line_no, @dr_account_key, @dr_account_label, @cr_account_key, @cr_account_label, @amount
          )
        '''),
        parameters: {
          'voucher_id': vid,
          'line_no': line['line_no'] ?? lineNo++,
          'dr_account_key': line['dr_account_key'],
          'dr_account_label': line['dr_account_label'],
          'cr_account_key': line['cr_account_key'],
          'cr_account_label': line['cr_account_label'],
          'amount': line['amount'] ?? 0,
        },
      );
    }
    return jsonOk({'id': vid, 'voucher': {'id': vid}}, status: 201);
  });
}
