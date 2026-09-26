import '../services/ultra_repository.dart';
import 'invoice.dart';
import 'ultra_print_helpers.dart';

String _billNo(Map<String, dynamic> note) {
  final stored = '${note['note_bill_no'] ?? ''}'.trim();
  if (stored.isNotEmpty) return stored;
  final uuid = '${note['uuid'] ?? ''}';
  final year = DateTime.tryParse('${note['issue_date']}')?.year ?? DateTime.now().year;
  final prefix = '${note['note_type']}' == 'DEBIT' ? 'DN' : 'CN';
  if (uuid.length >= 6) return '$prefix-$year-${uuid.replaceAll('-', '').substring(0, 6).toUpperCase()}';
  return '$prefix-$year-${note['note_no']}';
}

Future<void> reprintAdjustmentNote(int noteId) async {
  final data = await adjustmentNoteInvoiceData(noteId);
  if (data == null) return;
  await printUltraInvoice(data);
}

Future<InvoiceData?> adjustmentNoteInvoiceData(int noteId) async {
  final bundle = await UltraRepository.instance.adjustmentNotePrintBundle(noteId);
  if (bundle == null) return null;
  final note = bundle['note'] as Map<String, dynamic>;
  final rawItems = bundle['items'] as List<Map<String, dynamic>>;
  final isCredit = '${note['note_type']}' == 'CREDIT';

  final items = rawItems
      .map(
        (it) {
          final qty = (it['quantity'] as num?)?.toDouble() ?? 0;
          final rate = (it['rate'] as num?)?.toDouble() ?? 0;
          final ext = (it['extended_value'] as num?)?.toDouble();
          return InvoiceItem(
            description: '${it['description'] ?? ''}',
            hsnCode: '${it['hsn'] ?? ''}',
            qty: qty,
            price: rate,
          );
        },
      )
      .toList();

  final taxable = (note['taxable_total'] as num?)?.toDouble() ?? items.fold<double>(0, (s, i) => s + i.amount);
  final taxTotal = (note['tax_total'] as num?)?.toDouble() ?? 0;
  final grand = (note['grand_total'] as num?)?.toDouble() ?? taxable + taxTotal;
  final halfTax = taxTotal / 2;

  final address = [
    note['address'] ?? '',
    note['city'] ?? '',
    note['pincode'] ?? '',
  ].where((e) => '$e'.trim().isNotEmpty).join(', ');

  return InvoiceData(
    kind: isCredit ? UltraBillKind.creditNote : UltraBillKind.debitNote,
    documentTitle: isCredit ? 'CREDIT NOTE / SALES REVERSAL' : 'DEBIT NOTE / PURCHASE REVERSAL',
    partySectionTitle: isCredit ? 'NAME & ADDRESS OF CUSTOMER (CREDITED)' : 'NAME & ADDRESS OF SUPPLIER (DEBITED)',
    copyLabels: [
      isCredit ? 'DUPLICATE CLIENT REVERSAL COPY' : 'DUPLICATE SUPPLIER REVERSAL COPY',
    ],
    invoiceNo: _billNo(note),
    date: ultraFmtDate(note['issue_date'] as String?),
    origInvNo: '${note['original_invoice_ref'] ?? ''}',
    origInvDate: ultraFmtDate(note['original_invoice_date'] as String?),
    reason: '${note['reversal_reason'] ?? ''}',
    dispatch: '${note['logistics'] ?? ''}',
    ewbNo: '${note['eway_bill'] ?? ''}',
    consigneeName: '${note['party_name'] ?? ''}',
    consigneeAddress: address,
    gstin: '${note['gstin'] ?? ''}',
    mobile: '',
    items: items,
    cgstAmountOverride: halfTax,
    sgstAmountOverride: halfTax,
    grandTotalOverride: grand,
    amountInWords: formatUltraAmountInWords(grand),
    bankName: ultraDefaultBankName,
    accountNo: ultraDefaultBankAccount,
    ifscCode: ultraDefaultBankIfsc,
    bankAddress: ultraDefaultBankAddress,
    totalGrandLabel: 'Total Value',
  );
}
