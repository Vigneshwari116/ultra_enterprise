import 'package:postgres/postgres.dart';

import 'journal_writer.dart';
import 'ledger_service.dart';
import 'voucher_numbering.dart';

/// Salary voucher: Dr Salary, Cr Cash/Bank (gross amount only).
Future<void> postSalaryVoucher({
  required Session session,
  required int salaryVoucherId,
  required DateTime voucherDate,
  required int voucherNo,
  required String voucherNoDisplay,
  required double amount,
  required String cashBank,
  String? narration,
}) async {
  if (amount <= 0) throw ArgumentError('amount must be positive');

  final ledgers = await loadSystemLedgerIds(session);
  final cashLedgerId = cashBank.toUpperCase() == 'BANK' ? ledgers.bank : ledgers.cash;

  await deleteJournalForVoucher(
    session,
    voucherType: VoucherTypes.salary,
    voucherNo: voucherNo,
  );

  await insertJournalLines(
    session,
    voucherDate: voucherDate,
    voucherType: VoucherTypes.salary,
    voucherNo: voucherNo,
    voucherNoDisplay: voucherNoDisplay,
    sourceId: salaryVoucherId,
    narration: narration,
    lines: [
      JournalLineDraft(ledgerId: ledgers.salary, debit: amount),
      JournalLineDraft(ledgerId: cashLedgerId, credit: amount),
    ],
  );
}
