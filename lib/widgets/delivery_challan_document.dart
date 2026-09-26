import '../services/ultra_repository.dart';
import 'invoice.dart';
import 'ultra_print_helpers.dart';

Future<void> reprintDeliveryChallan(int challanId) async {
  final data = await deliveryChallanInvoiceData(challanId);
  if (data == null) return;
  await printUltraInvoice(data);
}

Future<InvoiceData?> deliveryChallanInvoiceData(int challanId) async {
  final bundle = await UltraRepository.instance.deliveryChallanPrintBundle(challanId);
  if (bundle == null) return null;
  final dc = bundle['challan'] as Map<String, dynamic>;
  final rawItems = bundle['items'] as List<Map<String, dynamic>>;

  final type = '${dc['dc_type']}';
  final title = type == 'PROFORMA' ? 'PROFORMA INVOICE' : 'DELIVERY CHALLAN';
  final copyLabel = switch (type) {
    'INWARD' => 'DUPLICATE DC INWARD LABELS',
    'OUTWARD' => 'DUPLICATE DC OUTWARD LABELS',
    'PROFORMA' => 'DUPLICATE PROFORMA LABELS',
    _ => 'DUPLICATE DELIVERY CHALLAN',
  };

  final items = rawItems
      .map(
        (it) => InvoiceItem(
          description: '${it['description'] ?? ''}',
          hsnCode: '${it['hsn'] ?? ''}',
          qty: (it['quantity'] as num?)?.toDouble() ?? 0,
          price: (it['rate'] as num?)?.toDouble() ?? 0,
          remarks: '${it['remarks'] ?? ''}',
        ),
      )
      .toList();

  final address = [
    dc['billing_address'] ?? '',
    dc['city'] ?? '',
    dc['pincode'] ?? '',
  ].where((e) => '$e'.trim().isNotEmpty).join(', ');

  final subtotal = (dc['base_value'] as num?)?.toDouble() ?? items.fold<double>(0, (s, i) => s + i.amount);
  final fwd = (dc['fwd_charge'] as num?)?.toDouble() ?? 0;
  final grand = (dc['grand_total'] as num?)?.toDouble() ?? subtotal + fwd;

  return InvoiceData(
    kind: UltraBillKind.deliveryChallan,
    documentTitle: title,
    partySectionTitle: 'NAME & ADDRESS OF RECEIVER',
    copyLabels: [copyLabel],
    invoiceNo: '${dc['doc_id'] ?? dc['serial_no'] ?? ''}',
    date: ultraFmtDate(dc['document_date'] as String?),
    custPo: '${dc['po_ref_no'] ?? ''}',
    poDate: ultraFmtDate(dc['po_ref_date'] as String?),
    dcNo: '${dc['account_ref'] ?? ''}',
    dcDate: ultraFmtDate(dc['po_ref_date'] as String?),
    dispatch: '${dc['vehicle_dispatch'] ?? ''}',
    ewbNo: '${dc['eway_bill_no'] ?? ''}',
    consigneeName: '${dc['party_name'] ?? ''}',
    consigneeAddress: address,
    gstin: '${dc['gstin'] ?? ''}',
    mobile: 'NOT AVAILABLE',
    items: items,
    pAndF: fwd,
    grandTotalOverride: grand,
    amountInWords: formatUltraAmountInWords(grand),
    bankName: ultraDefaultBankName,
    accountNo: ultraDefaultBankAccount,
    ifscCode: ultraDefaultBankIfsc,
    bankAddress: ultraDefaultBankAddress,
    forwardingLabel: 'Forwarding',
    totalGrandLabel: 'Total Value',
  );
}
