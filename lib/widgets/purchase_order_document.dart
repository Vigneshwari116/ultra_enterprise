import '../services/ultra_repository.dart';
import 'invoice.dart';
import 'transaction_line_math.dart';
import 'ultra_print_helpers.dart';

String _billNoForOrder(Map<String, dynamic> po) {
  final stored = '${po['po_bill_no'] ?? ''}'.trim();
  if (stored.isNotEmpty) return stored;
  final uuid = '${po['uuid'] ?? ''}';
  final year =
      DateTime.tryParse('${po['po_date']}')?.year ?? DateTime.now().year;
  if (uuid.length >= 6) {
    return 'PO-$year-${uuid.replaceAll('-', '').substring(0, 6).toUpperCase()}';
  }
  return 'PO-$year-${po['po_no'] ?? ''}';
}

Future<InvoiceData?> purchaseOrderDataFromId(int purchaseOrderId) async {
  final bundle = await UltraRepository.instance.purchaseOrderPrintBundle(
    purchaseOrderId,
  );
  if (bundle == null) return null;
  final po = bundle['order'] as Map<String, dynamic>;
  final rawItems = bundle['items'] as List<Map<String, dynamic>>;
  final items = rawItems
      .map(
        (it) => InvoiceItem(
          description: '${it['description'] ?? ''}',
          hsnCode: '${it['hsn'] ?? it['hsn_code'] ?? ''}',
          qty: coerceCatalogDouble(it['quantity']),
          price: coerceCatalogDouble(it['rate']),
        ),
      )
      .toList();

  final zone = '${po['state_zone'] ?? ''}'.toLowerCase();
  final isInter = zone.contains('inter');
  final supplierName =
      '${po['supplier_name'] ?? po['party_name'] ?? ''}'.trim();
  final address = [
    po['address'] ?? '',
    po['city'] ?? '',
    po['postal_pincode'] ?? '',
  ].where((e) => '$e'.trim().isNotEmpty).join(', ');

  final freight = coerceCatalogDouble(po['estimated_freight']);
  final subtotal = (po['taxable_total'] as num?)?.toDouble() ??
      items.fold<double>(0, (s, i) => s + i.amount);
  final cgstAmt = (po['cgst_total'] as num?)?.toDouble() ??
      (isInter ? 0.0 : subtotal * 0.09);
  final sgstAmt = (po['sgst_total'] as num?)?.toDouble() ??
      (isInter ? 0.0 : subtotal * 0.09);
  final igstAmt = (po['igst_total'] as num?)?.toDouble() ??
      (isInter ? subtotal * 0.18 : 0.0);
  final grand = (po['grand_total'] as num?)?.toDouble() ??
      subtotal + cgstAmt + sgstAmt + igstAmt + freight;
  final pAndF = freight > 0
      ? freight
      : (grand - subtotal - cgstAmt - sgstAmt - igstAmt).clamp(
          0,
          double.infinity,
        );

  double cgstPct = 0;
  double sgstPct = 0;
  double igstPct = 0;
  if (rawItems.isNotEmpty) {
    final line = rawItems.first;
    cgstPct = coerceCatalogDouble(line['cgst_percent']);
    sgstPct = coerceCatalogDouble(line['sgst_percent']);
    igstPct = coerceCatalogDouble(line['igst_percent']);
  }
  if (isInter) {
    if (igstPct <= 0 && (cgstPct + sgstPct) > 0) {
      igstPct = cgstPct + sgstPct;
    }
    cgstPct = 0;
    sgstPct = 0;
  } else if (subtotal > 0 && cgstAmt > 0 && cgstPct <= 0) {
    cgstPct = cgstAmt / subtotal * 100;
    sgstPct = sgstAmt / subtotal * 100;
  }

  return InvoiceData(
    kind: UltraBillKind.purchaseOrder,
    invoiceNo: _billNoForOrder(po),
    date: ultraFmtDate(po['po_date'] as String?),
    custPo: '${po['supplier_ref_no'] ?? ''}',
    poDate: ultraFmtDate(po['delivery_due_date'] as String?),
    dcNo: '${po['total_packages'] ?? ''}',
    dcDate: '',
    dispatch: '${po['delivery_mode'] ?? ''}',
    ewbNo: '${po['remarks'] ?? ''}',
    consigneeName: supplierName,
    consigneeAddress: address,
    gstin: '${po['gstin'] ?? ''}',
    mobile: '${po['primary_mobile'] ?? ''}',
    items: items,
    cgstPercent: cgstPct,
    sgstPercent: sgstPct,
    igstPercent: igstPct,
    pAndF: pAndF.toDouble(),
    cgstAmountOverride: cgstAmt,
    sgstAmountOverride: sgstAmt,
    igstAmountOverride: igstAmt,
    grandTotalOverride: grand,
    amountInWords: formatUltraAmountInWords(grand),
    bankName: ultraBankName(po, 'bank_name'),
    accountNo: ultraBankAccount(po, 'bank_account_no'),
    ifscCode: ultraBankIfsc(po, 'ifsc_code'),
    bankAddress: ultraBankAddress(po, 'branch_address'),
    documentTitle: 'PURCHASE ORDER',
    partySectionTitle: 'NAME & ADDRESS OF SUPPLIER',
    copyLabels: ultraPurchaseOrderCopyLabels,
    forwardingLabel: 'Estimated Freight',
    totalGrandLabel: 'Total Value',
    roundOff: (po['round_off'] as num?)?.toDouble() ?? 0,
  );
}

Future<void> reprintPurchaseOrder(int purchaseOrderId) async {
  final data = await purchaseOrderDataFromId(purchaseOrderId);
  if (data == null) return;
  await printUltraInvoice(data);
}
