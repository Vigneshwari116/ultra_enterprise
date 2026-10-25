import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../accounting/fy.dart';
import '../accounting/journal_writer.dart';
import '../accounting/post_salary.dart';
import '../accounting/voucher_numbering.dart';
import '../http.dart';

String _normalizeCashBank(Map<String, dynamic> body) {
  final raw = '${body['cash_bank'] ?? 'CASH'}'.toUpperCase();
  if (raw == 'BANK') return 'BANK';
  return 'CASH';
}

double _amount(dynamic v) => (v as num?)?.toDouble() ?? double.tryParse('$v') ?? 0;

void registerSalaryVoucherRoutes(Router router, Connection conn) {
  router.get('/api/salary-vouchers', (_) => listSalaryVouchers(conn));
  router.get('/api/salary-vouchers/<id>', (Request _, String id) async {
    final vid = int.tryParse(id);
    if (vid == null) return jsonError('Invalid salary voucher id', status: 400);
    return getSalaryVoucherById(conn, vid);
  });
  router.post('/api/salary-vouchers', (r) => createSalaryVoucher(r, conn));
  router.put('/api/salary-vouchers/<id>', (Request r, String id) async {
    final vid = int.tryParse(id);
    if (vid == null) return jsonError('Invalid salary voucher id', status: 400);
    return updateSalaryVoucher(r, conn, vid);
  });
  router.delete('/api/salary-vouchers/<id>', (Request _, String id) async {
    final vid = int.tryParse(id);
    if (vid == null) return jsonError('Invalid salary voucher id', status: 400);
    return deleteSalaryVoucher(conn, vid);
  });
}

Future<Response> listSalaryVouchers(Connection conn) async {
  final rows = await conn.execute('''
    SELECT id, uuid, voucher_no, voucher_no_display, voucher_date,
           amount, cash_bank, narration, created_at
    FROM salary_vouchers
    ORDER BY voucher_date DESC NULLS LAST, id DESC
  ''');
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}

Future<Response> getSalaryVoucherById(Connection conn, int id) async {
  final rows = await conn.execute(
    Sql.named('''
      SELECT id, uuid, voucher_no, voucher_no_display, voucher_date,
             amount, cash_bank, narration, created_at
      FROM salary_vouchers WHERE id = @id
    '''),
    parameters: {'id': id},
  );
  if (rows.isEmpty) {
    return jsonError('Salary voucher not found: $id', status: 404);
  }
  return jsonOk({'voucher': serializeRow(rows.first.toColumnMap())});
}

Future<Response> createSalaryVoucher(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  body.remove('voucher_no');
  body.remove('voucher_no_display');

  final amount = _amount(body['amount']);
  if (amount <= 0) return jsonError('amount must be greater than zero');
  if (body['voucher_date'] == null) return jsonError('voucher_date is required');

  final cashBank = _normalizeCashBank(body);
  final voucherDate = FinancialYear.parseVoucherDate(body['voucher_date']);

  try {
    return await conn.runTx((tx) async {
      final allocated = await allocateVoucherNumber(
        session: tx,
        voucherType: VoucherTypes.salary,
        voucherDate: voucherDate,
      );

      final result = await tx.execute(
        Sql.named('''
          INSERT INTO salary_vouchers (
            voucher_no, voucher_no_display, voucher_date,
            amount, cash_bank, narration, created_at
          ) VALUES (
            @voucher_no, @voucher_no_display, @voucher_date,
            @amount, @cash_bank, @narration, NOW()
          ) RETURNING id
        '''),
        parameters: {
          'voucher_no': allocated.sequence,
          'voucher_no_display': allocated.display,
          'voucher_date': body['voucher_date'],
          'amount': amount,
          'cash_bank': cashBank,
          'narration': body['narration'],
        },
      );
      final voucherId = (result.first.first as num).toInt();

      await postSalaryVoucher(
        session: tx,
        salaryVoucherId: voucherId,
        voucherDate: voucherDate,
        voucherNo: allocated.sequence,
        voucherNoDisplay: allocated.display,
        amount: amount,
        cashBank: cashBank,
        narration: body['narration']?.toString(),
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
    return jsonError('Salary voucher save failed: $e', status: 400);
  }
}

Future<Response> updateSalaryVoucher(
  Request request,
  Connection conn,
  int id,
) async {
  final body = await readJsonObject(request);
  body.remove('voucher_no');
  body.remove('voucher_no_display');

  final amount = _amount(body['amount']);
  if (amount <= 0) return jsonError('amount must be greater than zero');
  if (body['voucher_date'] == null) return jsonError('voucher_date is required');

  final cashBank = _normalizeCashBank(body);
  final voucherDate = FinancialYear.parseVoucherDate(body['voucher_date']);

  try {
    return await conn.runTx((tx) async {
      final existing = await tx.execute(
        Sql.named(
          'SELECT voucher_no, voucher_no_display FROM salary_vouchers WHERE id = @id',
        ),
        parameters: {'id': id},
      );
      if (existing.isEmpty) {
        return jsonError('Salary voucher not found: $id', status: 404);
      }
      final row = existing.first.toColumnMap();
      final voucherNo = (row['voucher_no'] as num).toInt();
      final voucherNoDisplay = '${row['voucher_no_display']}';

      await tx.execute(
        Sql.named('''
          UPDATE salary_vouchers SET
            voucher_date = @voucher_date,
            amount = @amount,
            cash_bank = @cash_bank,
            narration = @narration
          WHERE id = @id
        '''),
        parameters: {
          'id': id,
          'voucher_date': body['voucher_date'],
          'amount': amount,
          'cash_bank': cashBank,
          'narration': body['narration'],
        },
      );

      await deleteJournalForVoucher(
        tx,
        voucherType: VoucherTypes.salary,
        voucherNo: voucherNo,
      );
      await postSalaryVoucher(
        session: tx,
        salaryVoucherId: id,
        voucherDate: voucherDate,
        voucherNo: voucherNo,
        voucherNoDisplay: voucherNoDisplay,
        amount: amount,
        cashBank: cashBank,
        narration: body['narration']?.toString(),
      );

      return jsonOk({
        'id': id,
        'voucher': {
          'id': id,
          'voucher_no': voucherNo,
          'voucher_no_display': voucherNoDisplay,
        },
      });
    });
  } catch (e) {
    return jsonError('Salary voucher save failed: $e', status: 400);
  }
}

Future<Response> deleteSalaryVoucher(Connection conn, int id) async {
  try {
    return await conn.runTx((tx) async {
      final existing = await tx.execute(
        Sql.named('SELECT voucher_no FROM salary_vouchers WHERE id = @id'),
        parameters: {'id': id},
      );
      if (existing.isEmpty) {
        return jsonError('Salary voucher not found: $id', status: 404);
      }
      final voucherNo = (existing.first.first as num).toInt();

      await deleteJournalForVoucher(
        tx,
        voucherType: VoucherTypes.salary,
        voucherNo: voucherNo,
      );
      final deleted = await tx.execute(
        Sql.named('DELETE FROM salary_vouchers WHERE id = @id RETURNING id'),
        parameters: {'id': id},
      );
      if (deleted.isEmpty) {
        return jsonError('Salary voucher not found: $id', status: 404);
      }
      return jsonOk({'id': id, 'deleted': true});
    });
  } catch (e) {
    return jsonError('Salary voucher delete failed: $e', status: 400);
  }
}
