import 'package:postgres/postgres.dart';

import 'journal_writer.dart';
import 'ledger_service.dart';
import 'voucher_numbering.dart';

/// Payment: Dr Supplier, Cr Cash/Bank.
Future<void> postPayment({
  required Session session,
  required int paymentId,
  required int supplierId,
  required DateTime voucherDate,
  required int voucherNo,
  required String voucherNoDisplay,
  required double amount,
  required String cashBank,
  String? narration,
}) async {
  if (amount <= 0) throw ArgumentError('amount must be positive');

  final ledgers = await loadSystemLedgerIds(session);
  final supplierLedgerId = await ensureSupplierLedger(session, supplierId);
  final cashLedgerId = cashBank.toUpperCase() == 'BANK' ? ledgers.bank : ledgers.cash;

  await deleteJournalForVoucher(
    session,
    voucherType: VoucherTypes.payment,
    voucherNo: voucherNo,
  );

  await insertJournalLines(
    session,
    voucherDate: voucherDate,
    voucherType: VoucherTypes.payment,
    voucherNo: voucherNo,
    voucherNoDisplay: voucherNoDisplay,
    sourceId: paymentId,
    narration: narration,
    lines: [
      JournalLineDraft(ledgerId: supplierLedgerId, debit: amount),
      JournalLineDraft(ledgerId: cashLedgerId, credit: amount),
    ],
  );
}
