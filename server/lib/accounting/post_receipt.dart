import 'package:postgres/postgres.dart';

import 'journal_writer.dart';
import 'ledger_service.dart';
import 'voucher_numbering.dart';

/// Receipt: Dr Cash/Bank, Cr Customer.
Future<void> postReceipt({
  required Session session,
  required int receiptId,
  required int customerId,
  required DateTime voucherDate,
  required int voucherNo,
  required String voucherNoDisplay,
  required double amount,
  required String cashBank,
  String? narration,
}) async {
  if (amount <= 0) throw ArgumentError('amount must be positive');

  final ledgers = await loadSystemLedgerIds(session);
  final customerLedgerId = await ensureCustomerLedger(session, customerId);
  final cashLedgerId = cashBank.toUpperCase() == 'BANK' ? ledgers.bank : ledgers.cash;

  await deleteJournalForVoucher(
    session,
    voucherType: VoucherTypes.receipt,
    voucherNo: voucherNo,
  );

  await insertJournalLines(
    session,
    voucherDate: voucherDate,
    voucherType: VoucherTypes.receipt,
    voucherNo: voucherNo,
    voucherNoDisplay: voucherNoDisplay,
    sourceId: receiptId,
    narration: narration,
    lines: [
      JournalLineDraft(ledgerId: cashLedgerId, debit: amount),
      JournalLineDraft(ledgerId: customerLedgerId, credit: amount),
    ],
  );
}
