import 'package:postgres/postgres.dart';

import 'journal_writer.dart';
import 'ledger_service.dart';
import 'voucher_numbering.dart';

/// Sales posting (go-live only — no historical backfill).
///
/// Dr Customer (grand total)
/// Cr Sales (taxable)
/// Cr Output CGST / SGST / IGST (skip zero lines)
/// Cr Freight & Charges (when fwd_charge > 0)
Future<void> postSalesInvoice({
  required Session session,
  required int salesInvoiceId,
  required int customerId,
  required DateTime voucherDate,
  required int voucherNo,
  required String voucherNoDisplay,
  required double taxableTotal,
  required double cgstTotal,
  required double sgstTotal,
  required double igstTotal,
  required double fwdCharge,
  required double grandTotal,
  String? narration,
}) async {
  final ledgers = await loadSystemLedgerIds(session);
  final customerLedgerId = await ensureCustomerLedger(session, customerId);

  final taxSum = cgstTotal + sgstTotal + igstTotal;
  final expectedGrand = taxableTotal + taxSum + fwdCharge;
  if ((grandTotal - expectedGrand).abs() > 0.02) {
    throw StateError(
      'grand_total ($grandTotal) must equal taxable + tax + freight ($expectedGrand)',
    );
  }

  await deleteJournalForVoucher(
    session,
    voucherType: VoucherTypes.sales,
    voucherNo: voucherNo,
  );

  final lines = <JournalLineDraft>[
    JournalLineDraft(ledgerId: customerLedgerId, debit: grandTotal),
    if (taxableTotal > 0)
      JournalLineDraft(ledgerId: ledgers.sales, credit: taxableTotal),
    if (cgstTotal > 0)
      JournalLineDraft(ledgerId: ledgers.outputCgst, credit: cgstTotal),
    if (sgstTotal > 0)
      JournalLineDraft(ledgerId: ledgers.outputSgst, credit: sgstTotal),
    if (igstTotal > 0)
      JournalLineDraft(ledgerId: ledgers.outputIgst, credit: igstTotal),
    if (fwdCharge > 0)
      JournalLineDraft(ledgerId: ledgers.freight, credit: fwdCharge),
  ];

  await insertJournalLines(
    session,
    voucherDate: voucherDate,
    voucherType: VoucherTypes.sales,
    voucherNo: voucherNo,
    voucherNoDisplay: voucherNoDisplay,
    sourceId: salesInvoiceId,
    narration: narration,
    lines: lines,
  );
}
