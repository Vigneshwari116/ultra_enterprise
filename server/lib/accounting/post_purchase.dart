import 'package:postgres/postgres.dart';

import 'journal_writer.dart';
import 'ledger_service.dart';
import 'voucher_numbering.dart';

/// Purchase posting uses **header JSON totals only** (not item line sums).
///
/// Dr Purchase (taxable)
/// Dr Input CGST / SGST / IGST (skip zero)
/// Dr Freight (optional header key)
/// Dr/Cr Round Off (|diff| ≤ ₹1 vs taxable + tax + freight)
/// Cr Supplier (grand_total)
Future<void> postPurchaseVoucher({
  required Session session,
  required int purchaseVoucherId,
  required int supplierId,
  required DateTime voucherDate,
  required int voucherNo,
  required String voucherNoDisplay,
  required String status,
  required double taxableTotal,
  required double cgstTotal,
  required double sgstTotal,
  required double igstTotal,
  required double freight,
  required double grandTotal,
  String? narration,
}) async {
  if (status != 'POSTED') return;

  final ledgers = await loadSystemLedgerIds(session);
  final supplierLedgerId = await ensureSupplierLedger(session, supplierId);

  final taxSum = cgstTotal + sgstTotal + igstTotal;
  final expectedGrand = taxableTotal + taxSum + freight;
  final diff = grandTotal - expectedGrand;
  if (diff.abs() > 1.01) {
    throw StateError(
      'grand_total ($grandTotal) must be within ₹1 of taxable + tax + freight ($expectedGrand)',
    );
  }

  await deleteJournalForVoucher(
    session,
    voucherType: VoucherTypes.purchase,
    voucherNo: voucherNo,
  );

  final lines = <JournalLineDraft>[
    if (taxableTotal > 0)
      JournalLineDraft(ledgerId: ledgers.purchase, debit: taxableTotal),
    if (cgstTotal > 0)
      JournalLineDraft(ledgerId: ledgers.inputCgst, debit: cgstTotal),
    if (sgstTotal > 0)
      JournalLineDraft(ledgerId: ledgers.inputSgst, debit: sgstTotal),
    if (igstTotal > 0)
      JournalLineDraft(ledgerId: ledgers.inputIgst, debit: igstTotal),
    if (freight > 0)
      JournalLineDraft(ledgerId: ledgers.freight, debit: freight),
    if (diff > 0.001)
      JournalLineDraft(ledgerId: ledgers.roundOff, debit: diff),
    JournalLineDraft(ledgerId: supplierLedgerId, credit: grandTotal),
    if (diff < -0.001)
      JournalLineDraft(ledgerId: ledgers.roundOff, credit: -diff),
  ];

  await insertJournalLines(
    session,
    voucherDate: voucherDate,
    voucherType: VoucherTypes.purchase,
    voucherNo: voucherNo,
    voucherNoDisplay: voucherNoDisplay,
    sourceId: purchaseVoucherId,
    narration: narration,
    lines: lines,
  );
}
