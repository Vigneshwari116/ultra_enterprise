import '../services/ultra_repository.dart';
import 'invoice.dart';
import 'transaction_line_math.dart';
import 'ultra_print_helpers.dart';

Future<void> reprintDeliveryChallan(int challanId) async {
  final data = await deliveryChallanInvoiceData(challanId);
  if (data == null) {
    throw Exception('Delivery challan not found (id: $challanId)');
  }
  await layoutPrintUltraInvoice(data);
}

Future<InvoiceData?> deliveryChallanInvoiceData(int challanId) async {
  final bundle =
      await UltraRepository.instance.deliveryChallanPrintBundle(challanId);
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

  var cgstTotal = 0.0;
  var sgstTotal = 0.0;
  var igstTotal = 0.0;
  for (final it in rawItems) {
    final t = TransactionLineTotals.compute(
      qty: coerceCatalogDouble(it['quantity']),
      rate: coerceCatalogDouble(it['rate']),
      cgstPct: coerceCatalogDouble(it['cgst_percent'], fallback: 9),
      sgstPct: coerceCatalogDouble(it['sgst_percent'], fallback: 9),
      igstPct: coerceCatalogDouble(it['igst_percent']),
    );
    cgstTotal += t.cgst;
    sgstTotal += t.sgst;
    igstTotal += t.igst;
  }

  final address = [
    dc['billing_address'] ?? '',
    dc['city'] ?? '',
    dc['pincode'] ?? '',
  ].where((e) => '$e'.trim().isNotEmpty).join(', ');

  final subtotal = (dc['base_value'] as num?)?.toDouble() ??
      items.fold<double>(0, (s, i) => s + i.amount);
  final fwd = (dc['fwd_charge'] as num?)?.toDouble() ?? 0;
  final grand = (dc['grand_total'] as num?)?.toDouble() ??
      subtotal + cgstTotal + sgstTotal + igstTotal + fwd;
  final validityDays = '${dc['validity_days'] ?? '0'}';

  return InvoiceData(
    kind: UltraBillKind.deliveryChallan,
    documentTitle: title,
    partySectionTitle: 'NAME & ADDRESS OF RECEIVER',
    copyLabels: ['ORIGINAL $title', copyLabel],
    invoiceNo: '${dc['doc_id'] ?? dc['serial_no'] ?? ''}',
    date: ultraFmtDate(dc['document_date'] as String?),
    custPo: '${dc['po_ref_no'] ?? ''}',
    poDate: ultraFmtDate(dc['po_ref_date'] as String?),
    dcNo: '${dc['account_ref'] ?? ''}',
    dcDate: ultraFmtDate(dc['po_ref_date'] as String?),
    dispatch: '${dc['vehicle_dispatch'] ?? ''}',
    ewbNo: type == 'PROFORMA' && validityDays != '0'
        ? 'VALIDITY: $validityDays DAYS'
        : '${dc['eway_bill_no'] ?? ''}',
    consigneeName: '${dc['party_name'] ?? ''}',
    consigneeAddress: address,
    gstin: '${dc['gstin'] ?? ''}',
    mobile: 'NOT AVAILABLE',
    items: items,
    pAndF: fwd,
    cgstAmountOverride: cgstTotal,
    sgstAmountOverride: sgstTotal,
    igstAmountOverride: igstTotal,
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
