import 'package:postgres/postgres.dart';

class JournalLineDraft {
  final int ledgerId;
  final double debit;
  final double credit;

  JournalLineDraft({
    required this.ledgerId,
    this.debit = 0,
    this.credit = 0,
  });
}

void assertJournalBalanced(List<JournalLineDraft> lines) {
  var dr = 0.0;
  var cr = 0.0;
  for (final l in lines) {
    dr += l.debit;
    cr += l.credit;
  }
  if ((dr - cr).abs() > 0.01) {
    throw StateError('Journal not balanced: debit=$dr credit=$cr');
  }
}

Future<void> deleteJournalForVoucher(
  Session session, {
  required String voucherType,
  required int voucherNo,
}) async {
  await session.execute(
    Sql.named('''
      DELETE FROM journal_entries
      WHERE voucher_type = @type AND voucher_no = @no
    '''),
    parameters: {'type': voucherType, 'no': voucherNo},
  );
}

Future<void> insertJournalLines(
  Session session, {
  required DateTime voucherDate,
  required String voucherType,
  required int voucherNo,
  required String voucherNoDisplay,
  required int sourceId,
  String? narration,
  required List<JournalLineDraft> lines,
}) async {
  assertJournalBalanced(lines);
  final date = DateTime.utc(voucherDate.year, voucherDate.month, voucherDate.day);
  for (final line in lines) {
    if (line.debit <= 0 && line.credit <= 0) continue;
    await session.execute(
      Sql.named('''
        INSERT INTO journal_entries (
          date, voucher_type, voucher_no, voucher_no_display,
          ledger_id, debit, credit, narration, source_id
        ) VALUES (
          @date, @voucher_type, @voucher_no, @voucher_no_display,
          @ledger_id, @debit, @credit, @narration, @source_id
        )
      '''),
      parameters: {
        'date': date,
        'voucher_type': voucherType,
        'voucher_no': voucherNo,
        'voucher_no_display': voucherNoDisplay,
        'ledger_id': line.ledgerId,
        'debit': line.debit,
        'credit': line.credit,
        'narration': narration,
        'source_id': sourceId,
      },
    );
  }
}
