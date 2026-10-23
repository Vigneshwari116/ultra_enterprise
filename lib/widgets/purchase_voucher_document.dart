import '../services/ultra_repository.dart';
import '../utils/voucher_display.dart';
import 'invoice.dart';
import 'ultra_print_helpers.dart';

Future<InvoiceData?> purchaseVoucherInvoiceData(int voucherId) async {
  final bundle =
      await UltraRepository.instance.purchaseVoucherPrintBundle(voucherId);
  if (bundle == null) return null;
  final v = bundle['voucher'] as Map<String, dynamic>;
  final rawItems = bundle['items'] as List<Map<String, dynamic>>;

  final items = rawItems
      .map(
        (it) => InvoiceItem(
          description: '${it['description'] ?? ''}',
          hsnCode: '${it['hsn'] ?? ''}',
          qty: parseApiAmount(it['quantity']),
          price: parseApiAmount(it['rate']),
        ),
      )
      .toList();

  final address = [
    v['address'] ?? '',
    v['city'] ?? '',
    v['postal_pincode'] ?? '',
  ].where((e) => '$e'.trim().isNotEmpty).join(', ');

  final taxable = (v['taxable_total'] as num?)?.toDouble() ??
      items.fold<double>(0, (s, i) => s + i.amount);
  final cgstAmt = parseApiAmount(v['cgst_total']);
  final sgstAmt = parseApiAmount(v['sgst_total']);
  final igstAmt = parseApiAmount(v['igst_total']);
  final grand = (v['grand_total'] as num?)?.toDouble() ??
      taxable + cgstAmt + sgstAmt + igstAmt;
  final hasIgst = igstAmt > 0;

  return InvoiceData(
    kind: UltraBillKind.purchaseVoucher,
    documentTitle: 'PURCHASE VOUCHER',
    partySectionTitle: 'NAME & ADDRESS OF SUPPLIER',
    copyLabels: ultraOriginalDuplicateLabels(
      'PURCHASE VOUCHER',
      duplicateLabel: 'DUPLICATE PURCHASE VOUCHER COPY',
    ),
    invoiceNo: purchaseVoucherDisplayNo(v),
    date: ultraFmtDate(v['voucher_date'] as String?),
    custPo: '${v['supplier_invoice_no'] ?? ''}',
    poDate: ultraFmtDate(v['supplier_invoice_date'] as String?),
    dcNo: '${v['linked_po_no'] ?? ''}',
    dcDate: ultraFmtDate(v['linked_po_date'] as String?),
    dispatch: '',
    ewbNo: '',
    consigneeName: '${v['supplier_name'] ?? ''}',
    consigneeAddress: address,
    gstin: '${v['gstin'] ?? ''}',
    mobile: '${v['primary_mobile'] ?? ''}',
    items: items,
    cgstPercent: hasIgst ? 0 : 9,
    sgstPercent: hasIgst ? 0 : 9,
    igstPercent: hasIgst ? 18 : 0,
    cgstAmountOverride: cgstAmt,
    sgstAmountOverride: sgstAmt,
    igstAmountOverride: igstAmt,
    grandTotalOverride: grand,
    amountInWords: formatUltraAmountInWords(grand),
    bankName: ultraBankName(v, 'bank_name'),
    accountNo: ultraBankAccount(v, 'bank_account_no'),
    ifscCode: ultraBankIfsc(v, 'ifsc_code'),
    bankAddress: ultraBankAddress(v, 'branch_address'),
    totalGrandLabel: 'Total Value',
    roundOff: parseApiAmount(v['round_off']),
  );
}

Future<void> reprintPurchaseVoucher(int voucherId) async {
  final data = await purchaseVoucherInvoiceData(voucherId);
  if (data == null) return;
  await printUltraInvoice(data);
}
