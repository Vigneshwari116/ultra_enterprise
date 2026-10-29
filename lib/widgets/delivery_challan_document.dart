import 'package:flutter/material.dart';

import '../config/ultra_company_constants.dart';
import '../services/ultra_repository.dart';
import '../utils/voucher_display.dart';
import 'invoice.dart';
import 'transaction_line_math.dart';
import 'ultra_print_helpers.dart';

Future<void> reprintDeliveryChallan(BuildContext context, int challanId) async {
  final data = await deliveryChallanInvoiceData(challanId);
  if (data == null) {
    throw Exception('Delivery challan not found (id: $challanId)');
  }
  await printInvoiceDataDocument(context, data);
}

Future<InvoiceData?> deliveryChallanInvoiceData(int challanId) async {
  final bundle =
      await UltraRepository.instance.deliveryChallanPrintBundle(challanId);
  if (bundle == null) return null;
  final dc = bundle['challan'] as Map<String, dynamic>;
  final rawItems = bundle['items'] as List<Map<String, dynamic>>;

  final type = '${dc['dc_type']}';
  if (type == 'PROFORMA') {
    return _proformaInvoiceData(dc, rawItems);
  }

  final inward = type == 'INWARD';
  final title =
      inward ? 'DELIVERY CHALLAN - INWARD' : 'DELIVERY CHALLAN';

  final items = rawItems
      .map(
        (it) => InvoiceItem(
          description: pdfLatin1('${it['description'] ?? ''}'),
          hsnCode: pdfLatin1('${it['hsn'] ?? ''}'),
          qty: parseApiAmount(it['quantity']),
          price: parseApiAmount(it['rate']),
          remarks: pdfLatin1('${it['remarks'] ?? ''}'),
        ),
      )
      .toList();

  final address = [
    dc['billing_address'] ?? '',
    dc['city'] ?? '',
    dc['pincode'] ?? '',
  ].where((e) => '$e'.trim().isNotEmpty).join(', ');

  final serial = '${dc['serial_no'] ?? ''}'.trim();
  final docDate = dc['document_date'] as String?;
  final created = dc['created_at'] as String?;

  return InvoiceData(
    kind: UltraBillKind.deliveryChallan,
    documentTitle: title,
    copyLabels: [title],
    invoiceNo: serial.isEmpty ? '${dc['id'] ?? ''}' : serial,
    date: formatUltraDcDateTime(docDate, fallbackTime: DateTime.tryParse(created ?? '')),
    custPo: '${dc['account_ref'] ?? ''}',
    poDate: formatUltraDcPoDate(dc['account_ref_date'] as String? ?? dc['po_ref_date'] as String?),
    dcNo: '${dc['po_ref_no'] ?? ''}',
    dcDate: formatUltraDcPoDate(dc['po_ref_date'] as String?),
    dispatch: printableDispatch(dc['vehicle_dispatch']),
    ewbNo: '${dc['eway_bill_no'] ?? ''}',
    consigneeName: pdfLatin1('${dc['party_name'] ?? ''}'),
    consigneeAddress: pdfLatin1(address),
    gstin: pdfLatin1('${dc['gstin'] ?? ''}'),
    items: items,
    amountInWords: '',
    bankName: UltraCompanyConstants.bankName,
    accountNo: UltraCompanyConstants.bankAccountNo,
    ifscCode: UltraCompanyConstants.bankIfsc,
    bankAddress: UltraCompanyConstants.bankBranch,
  );
}

InvoiceData _proformaInvoiceData(
  Map<String, dynamic> dc,
  List<Map<String, dynamic>> rawItems,
) {
  final items = rawItems
      .map(
        (it) => InvoiceItem(
          description: pdfLatin1('${it['description'] ?? ''}'),
          hsnCode: pdfLatin1('${it['hsn'] ?? ''}'),
          qty: parseApiAmount(it['quantity']),
          price: parseApiAmount(it['rate']),
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
  final fwd = parseApiAmount(dc['fwd_charge']);
  final grand = subtotal + cgstTotal + sgstTotal + igstTotal + fwd;
  final pct = taxPercentsFromTotals(
    taxable: subtotal,
    cgst: cgstTotal,
    sgst: sgstTotal,
    igst: igstTotal,
  );

  final city = '${dc['city'] ?? ''}'.trim();
  final pin = '${dc['pincode'] ?? ''}'.trim();
  final cityLine = [
    if (city.isNotEmpty) city,
    if (pin.isNotEmpty) pin,
  ].join(' - ');

  return InvoiceData(
    kind: UltraBillKind.deliveryChallan,
    salesBillType: UltraSalesBillType.proforma,
    documentTitle: 'PROFORMA INVOICE',
    copyLabels: ultraSalesBillCopyLabels,
    invoiceNo: '${dc['serial_no'] ?? dc['doc_id'] ?? ''}',
    date: formatUltraBillDateShort(dc['document_date'] as String?),
    custPo: '${dc['po_ref_no'] ?? ''}',
    poDate: formatUltraBillDateShort(dc['po_ref_date'] as String?),
    dcNo: printableDcReference('${dc['po_ref_no'] ?? ''}'),
    dcDate: formatUltraBillDateShort(dc['po_ref_date'] as String?),
    dispatch: printableDispatch(dc['vehicle_dispatch']),
    ewbNo: '${dc['eway_bill_no'] ?? ''}',
    consigneeName: pdfLatin1('${dc['party_name'] ?? ''}'),
    consigneeAddress: pdfLatin1(address),
    consigneeCityLine: pdfLatin1(cityLine),
    gstin: pdfLatin1('${dc['gstin'] ?? ''}'),
    mobile: '',
    items: items,
    pAndF: fwd,
    cgstPercent: pct.cgst,
    sgstPercent: pct.sgst,
    igstPercent: pct.igst,
    cgstAmountOverride: cgstTotal,
    sgstAmountOverride: sgstTotal,
    igstAmountOverride: igstTotal,
    grandTotalOverride: grand,
    amountInWords: formatUltraAmountInWords(grand),
    bankName: UltraCompanyConstants.bankName,
    accountNo: UltraCompanyConstants.bankAccountNo,
    ifscCode: UltraCompanyConstants.bankIfsc,
    bankAddress: UltraCompanyConstants.bankBranch,
    leftSignatureLabel: 'Receiver signature & Seal',
  );
}
