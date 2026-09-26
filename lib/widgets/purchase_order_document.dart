import '../services/ultra_repository.dart';
import 'invoice.dart';
import 'ultra_print_helpers.dart';

String _billNoForOrder(Map<String, dynamic> po) {
  final stored = '${po['po_bill_no'] ?? ''}'.trim();
  if (stored.isNotEmpty) return stored;
  final uuid = '${po['uuid'] ?? ''}';
  final year = DateTime.tryParse('${po['po_date']}')?.year ?? DateTime.now().year;
  if (uuid.length >= 6) {
    return 'PO-$year-${uuid.replaceAll('-', '').substring(0, 6).toUpperCase()}';
  }
  return 'PO-$year-${po['po_no'] ?? ''}';
}

Future<InvoiceData?> purchaseOrderDataFromId(int purchaseOrderId) async {
  final bundle = await UltraRepository.instance.purchaseOrderPrintBundle(purchaseOrderId);
  if (bundle == null) return null;
  final po = bundle['order'] as Map<String, dynamic>;
  final rawItems = bundle['items'] as List<Map<String, dynamic>>;
  final items = rawItems
      .map(
        (it) => InvoiceItem(
          description: '${it['description'] ?? ''}',
          hsnCode: '${it['hsn'] ?? ''}',
          qty: (it['quantity'] as num?)?.toDouble() ?? 0,
          price: (it['rate'] as num?)?.toDouble() ?? 0,
        ),
      )
      .toList();

  final zone = '${po['state_zone'] ?? ''}'.toLowerCase();
  final isInter = zone.contains('inter');
  final address = [
    po['address'] ?? '',
    po['city'] ?? '',
    po['postal_pincode'] ?? '',
  ].where((e) => '$e'.trim().isNotEmpty).join(', ');

  final freight = (po['estimated_freight'] as num?)?.toDouble() ?? 0;
  final subtotal = items.fold<double>(0, (s, i) => s + i.amount);
  final cgstAmt = isInter ? 0.0 : subtotal * 0.09;
  final sgstAmt = isInter ? 0.0 : subtotal * 0.09;
  final igstAmt = isInter ? subtotal * 0.18 : 0.0;
  final grand = subtotal + cgstAmt + sgstAmt + igstAmt + freight;

  return InvoiceData(
    kind: UltraBillKind.purchaseOrder,
    invoiceNo: _billNoForOrder(po),
    date: ultraFmtDate(po['po_date'] as String?),
    custPo: '${po['supplier_ref_no'] ?? ''}',
    poDate: ultraFmtDate(po['delivery_due_date'] as String?),
    dcNo: '${po['total_packages'] ?? ''}',
    dcDate: '',
    dispatch: '${po['delivery_mode'] ?? ''}',
    ewbNo: '',
    consigneeName: '${po['supplier_name'] ?? ''}',
    consigneeAddress: address,
    gstin: '${po['gstin'] ?? ''}',
    mobile: '${po['primary_mobile'] ?? ''}',
    items: items,
    cgstPercent: isInter ? 0 : 9,
    sgstPercent: isInter ? 0 : 9,
    igstPercent: isInter ? 18 : 0,
    pAndF: freight,
    amountInWords: formatUltraAmountInWords(grand),
    bankName: ultraBankName(po, 'bank_name'),
    accountNo: ultraBankAccount(po, 'bank_account_no'),
    ifscCode: ultraBankIfsc(po, 'ifsc_code'),
    bankAddress: ultraBankAddress(po, 'branch_address'),
    documentTitle: 'PURCHASE ORDER',
    partySectionTitle: 'NAME & ADDRESS OF SUPPLIER',
    copyLabels: const ['ORIGINAL FOR SUPPLIER'],
  );
}

Future<void> reprintPurchaseOrder(int purchaseOrderId) async {
  final data = await purchaseOrderDataFromId(purchaseOrderId);
  if (data == null) return;
  await printUltraInvoice(data);
}
