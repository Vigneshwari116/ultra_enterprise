import 'package:postgres/postgres.dart';

import 'journal_writer.dart';
import 'ledger_service.dart';
import 'voucher_numbering.dart';

/// Expense voucher: Dr expense ledger, Cr Cash/Bank.
Future<void> postExpenseVoucher({
  required Session session,
  required int expenseVoucherId,
  required int expenseLedgerId,
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
    voucherType: VoucherTypes.expense,
    voucherNo: voucherNo,
  );

  await insertJournalLines(
    session,
    voucherDate: voucherDate,
    voucherType: VoucherTypes.expense,
    voucherNo: voucherNo,
    voucherNoDisplay: voucherNoDisplay,
    sourceId: expenseVoucherId,
    narration: narration,
    lines: [
      JournalLineDraft(ledgerId: expenseLedgerId, debit: amount),
      JournalLineDraft(ledgerId: cashLedgerId, credit: amount),
    ],
  );
}
