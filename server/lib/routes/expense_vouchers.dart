import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../accounting/fy.dart';
import '../accounting/journal_writer.dart';
import '../accounting/ledger_service.dart';
import '../accounting/post_expense.dart';
import '../accounting/voucher_numbering.dart';
import '../http.dart';

String _normalizeCashBank(Map<String, dynamic> body) {
  final raw = '${body['cash_bank'] ?? 'CASH'}'.toUpperCase();
  if (raw == 'BANK') return 'BANK';
  return 'CASH';
}

double _amount(dynamic v) => (v as num?)?.toDouble() ?? double.tryParse('$v') ?? 0;

void registerExpenseVoucherRoutes(Router router, Connection conn) {
  router.get('/api/expense-ledgers', (_) => listExpenseLedgers(conn));
  router.get('/api/expense-vouchers', (_) => listExpenseVouchers(conn));
  router.get('/api/expense-vouchers/<id>', (Request _, String id) async {
    final vid = int.tryParse(id);
    if (vid == null) return jsonError('Invalid expense voucher id', status: 400);
    return getExpenseVoucherById(conn, vid);
  });
  router.post('/api/expense-vouchers', (r) => createExpenseVoucher(r, conn));
  router.put('/api/expense-vouchers/<id>', (Request r, String id) async {
    final vid = int.tryParse(id);
    if (vid == null) return jsonError('Invalid expense voucher id', status: 400);
    return updateExpenseVoucher(r, conn, vid);
  });
  router.delete('/api/expense-vouchers/<id>', (Request _, String id) async {
    final vid = int.tryParse(id);
    if (vid == null) return jsonError('Invalid expense voucher id', status: 400);
    return deleteExpenseVoucher(conn, vid);
  });
}

Future<Response> listExpenseLedgers(Connection conn) async {
  final rows = await conn.execute('''
    SELECT id, name, group_type, system_key
    FROM ledgers
    WHERE group_type = 'expense'
    ORDER BY name
  ''');
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}

Future<Response> listExpenseVouchers(Connection conn) async {
  final rows = await conn.execute('''
    SELECT ev.id, ev.uuid, ev.voucher_no, ev.voucher_no_display, ev.voucher_date,
           ev.expense_ledger_id, ev.amount, ev.cash_bank, ev.narration, ev.created_at,
           l.name AS expense_ledger_name
    FROM expense_vouchers ev
    JOIN ledgers l ON l.id = ev.expense_ledger_id
    ORDER BY ev.voucher_date DESC NULLS LAST, ev.id DESC
  ''');
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}

Future<Response> getExpenseVoucherById(Connection conn, int id) async {
  final rows = await conn.execute(
    Sql.named('''
      SELECT ev.id, ev.uuid, ev.voucher_no, ev.voucher_no_display, ev.voucher_date,
             ev.expense_ledger_id, ev.amount, ev.cash_bank, ev.narration, ev.created_at,
             l.name AS expense_ledger_name
      FROM expense_vouchers ev
      JOIN ledgers l ON l.id = ev.expense_ledger_id
      WHERE ev.id = @id
    '''),
    parameters: {'id': id},
  );
  if (rows.isEmpty) {
    return jsonError('Expense voucher not found: $id', status: 404);
  }
  return jsonOk({'voucher': serializeRow(rows.first.toColumnMap())});
}

Future<Response> createExpenseVoucher(Request request, Connection conn) async {
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
      final expenseLedgerId = await resolveExpenseLedgerId(
        tx,
        body['expense_ledger_id'],
      );

      final allocated = await allocateVoucherNumber(
        session: tx,
        voucherType: VoucherTypes.expense,
        voucherDate: voucherDate,
      );

      final result = await tx.execute(
        Sql.named('''
          INSERT INTO expense_vouchers (
            voucher_no, voucher_no_display, voucher_date, expense_ledger_id,
            amount, cash_bank, narration, created_at
          ) VALUES (
            @voucher_no, @voucher_no_display, @voucher_date, @expense_ledger_id,
            @amount, @cash_bank, @narration, NOW()
          ) RETURNING id
        '''),
        parameters: {
          'voucher_no': allocated.sequence,
          'voucher_no_display': allocated.display,
          'voucher_date': body['voucher_date'],
          'expense_ledger_id': expenseLedgerId,
          'amount': amount,
          'cash_bank': cashBank,
          'narration': body['narration'],
        },
      );
      final voucherId = (result.first.first as num).toInt();

      await postExpenseVoucher(
        session: tx,
        expenseVoucherId: voucherId,
        expenseLedgerId: expenseLedgerId,
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
    return jsonError('Expense voucher save failed: $e', status: 400);
  }
}

Future<Response> updateExpenseVoucher(
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
          'SELECT voucher_no, voucher_no_display FROM expense_vouchers WHERE id = @id',
        ),
        parameters: {'id': id},
      );
      if (existing.isEmpty) {
        return jsonError('Expense voucher not found: $id', status: 404);
      }
      final row = existing.first.toColumnMap();
      final voucherNo = (row['voucher_no'] as num).toInt();
      final voucherNoDisplay = '${row['voucher_no_display']}';

      final expenseLedgerId = await resolveExpenseLedgerId(
        tx,
        body['expense_ledger_id'],
      );

      await tx.execute(
        Sql.named('''
          UPDATE expense_vouchers SET
            voucher_date = @voucher_date,
            expense_ledger_id = @expense_ledger_id,
            amount = @amount,
            cash_bank = @cash_bank,
            narration = @narration
          WHERE id = @id
        '''),
        parameters: {
          'id': id,
          'voucher_date': body['voucher_date'],
          'expense_ledger_id': expenseLedgerId,
          'amount': amount,
          'cash_bank': cashBank,
          'narration': body['narration'],
        },
      );

      await deleteJournalForVoucher(
        tx,
        voucherType: VoucherTypes.expense,
        voucherNo: voucherNo,
      );
      await postExpenseVoucher(
        session: tx,
        expenseVoucherId: id,
        expenseLedgerId: expenseLedgerId,
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
    return jsonError('Expense voucher save failed: $e', status: 400);
  }
}

Future<Response> deleteExpenseVoucher(Connection conn, int id) async {
  try {
    return await conn.runTx((tx) async {
      final existing = await tx.execute(
        Sql.named('SELECT voucher_no FROM expense_vouchers WHERE id = @id'),
        parameters: {'id': id},
      );
      if (existing.isEmpty) {
        return jsonError('Expense voucher not found: $id', status: 404);
      }
      final voucherNo = (existing.first.first as num).toInt();

      await deleteJournalForVoucher(
        tx,
        voucherType: VoucherTypes.expense,
        voucherNo: voucherNo,
      );
      final deleted = await tx.execute(
        Sql.named('DELETE FROM expense_vouchers WHERE id = @id RETURNING id'),
        parameters: {'id': id},
      );
      if (deleted.isEmpty) {
        return jsonError('Expense voucher not found: $id', status: 404);
      }
      return jsonOk({'id': id, 'deleted': true});
    });
  } catch (e) {
    return jsonError('Expense voucher delete failed: $e', status: 400);
  }
}
