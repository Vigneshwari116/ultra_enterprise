import 'package:intl/intl.dart';
import '../services/ultra_repository.dart';
import 'invoice.dart';

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return DateFormat('dd-MM-yyyy').format(d);
}

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

  return InvoiceData(
    invoiceNo: _billNoForOrder(po),
    date: _fmtDate(po['po_date'] as String?),
    custPo: '${po['supplier_ref_no'] ?? ''}',
    poDate: _fmtDate(po['delivery_due_date'] as String?),
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
    amountInWords: 'RUPEES ONLY',
    bankName: '${po['bank_name'] ?? ''}',
    accountNo: '${po['bank_account_no'] ?? ''}',
    ifscCode: '${po['ifsc_code'] ?? ''}',
    bankAddress: '${po['branch_address'] ?? ''}',
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
