import '../services/ultra_repository.dart';
import 'invoice.dart';
import 'ultra_print_helpers.dart';

Future<void> reprintQuotation(int quotationId) async {
  final data = await quotationInvoiceData(quotationId);
  if (data == null) return;
  await printUltraInvoice(data);
}

Future<InvoiceData?> quotationInvoiceData(int quotationId) async {
  final bundle = await UltraRepository.instance.quotationPrintBundle(quotationId);
  if (bundle == null) return null;
  final q = bundle['quotation'] as Map<String, dynamic>;
  final rawItems = bundle['items'] as List<Map<String, dynamic>>;
  final termRows = bundle['terms'] as List<Map<String, dynamic>>;

  final items = rawItems
      .map(
        (it) => InvoiceItem(
          description: '${it['description'] ?? ''}',
          hsnCode: '',
          qty: (it['quantity'] as num?)?.toDouble() ?? 0,
          price: (it['rate'] as num?)?.toDouble() ?? 0,
        ),
      )
      .toList();

  final address = [
    q['address'] ?? '',
    q['city'] ?? '',
    q['pincode'] ?? '',
  ].where((e) => '$e'.trim().isNotEmpty).join(', ');

  final freight = (q['freight'] as num?)?.toDouble() ?? 0;
  final subtotal = items.fold<double>(0, (s, i) => s + i.amount);
  final grand = (q['net_total'] as num?)?.toDouble() ?? subtotal + freight;

  final preamble = <String>[
    if ('${q['salutation'] ?? ''}'.trim().isNotEmpty) '${q['salutation']}',
    if ('${q['subject'] ?? ''}'.trim().isNotEmpty) 'Sub: ${q['subject']}',
    if ('${q['body_text'] ?? ''}'.trim().isNotEmpty) '${q['body_text']}',
  ];

  final customTerms = termRows
      .map((t) {
        final text = '${t['text'] ?? ''}'.trim();
        if (text.isEmpty) return '';
        return text.startsWith('.') ? text : '.$text';
      })
      .where((t) => t.isNotEmpty)
      .toList();

  final validityDays = '${q['validity_days'] ?? '0'}';
  final refName = '${q['reference_name'] ?? ''}';

  return InvoiceData(
    kind: UltraBillKind.quotation,
    documentTitle: 'QUOTATION',
    partySectionTitle: 'CUSTOMER / PARTY DETAILS',
    copyLabels: const ['DUPLICATE QUOTATION REPRINT'],
    invoiceNo: '${q['serial_no'] ?? q['ref_no'] ?? ''}',
    date: ultraFmtDate(q['quotation_date'] as String?),
    custPo: '${q['ref_no'] ?? ''}',
    poDate: ultraFmtDate(q['reference_date'] as String?),
    dispatch: refName,
    ewbNo: '$validityDays DAYS',
    consigneeName: '${q['party_name'] ?? ''} (${q['party_kind'] ?? ''})',
    consigneeAddress: address,
    gstin: '${q['gstin'] ?? ''}',
    mobile: '',
    items: items,
    pAndF: freight,
    grandTotalOverride: grand,
    amountInWords: formatUltraAmountInWords(grand),
    bankName: ultraDefaultBankName,
    accountNo: ultraDefaultBankAccount,
    ifscCode: ultraDefaultBankIfsc,
    bankAddress: ultraDefaultBankAddress,
    preambleLines: preamble,
    customTerms: customTerms.isEmpty ? null : customTerms,
    leftSignatureLabel: 'Prepared By',
    forwardingLabel: 'Forwarding',
    totalGrandLabel: 'Total Cost',
  );
}
