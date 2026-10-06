import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_enterprise/widgets/invoice.dart';

const _sampleItem = InvoiceItem(
  description: 'Test Product',
  hsnCode: '8481',
  qty: 2,
  price: 1000,
);

InvoiceData _baseData({
  UltraBillKind kind = UltraBillKind.taxInvoice,
  String documentTitle = 'TAX INVOICE',
  List<String>? copyLabels,
  String partySectionTitle = 'NAME & ADDRESS OF CONSIGNEE',
}) =>
    InvoiceData(
      kind: kind,
      documentTitle: documentTitle,
      partySectionTitle: partySectionTitle,
      copyLabels: copyLabels ?? ultraInvoiceCopyLabels,
      invoiceNo: 'DOC-001',
      date: '10/06/2025',
      dispatch: 'Road',
      consigneeName: 'Test Party',
      consigneeAddress: '123 Test Street, Bangalore',
      gstin: '29ABCDE1234F1Z5',
      mobile: '9876543210',
      items: const [_sampleItem],
      amountInWords: 'TWO THOUSAND RUPEES ONLY',
      bankName: 'Test Bank',
      accountNo: '1234567890',
      ifscCode: 'TEST0001234',
      bankAddress: 'Bangalore',
    );

void main() {
  final cases = <String, InvoiceData>{
    'tax invoice': _baseData(),
    'purchase order': _baseData(
      kind: UltraBillKind.purchaseOrder,
      documentTitle: 'PURCHASE ORDER',
      partySectionTitle: 'SUPPLIER DETAILS',
      copyLabels: ultraPurchaseOrderCopyLabels,
    ),
    'purchase voucher': _baseData(
      kind: UltraBillKind.purchaseVoucher,
      documentTitle: 'PURCHASE VOUCHER',
      partySectionTitle: 'SUPPLIER DETAILS',
      copyLabels: const ['ORIGINAL PURCHASE VOUCHER'],
    ),
    'quotation': _baseData(
      kind: UltraBillKind.quotation,
      documentTitle: 'QUOTATION',
      copyLabels: const ['ORIGINAL QUOTATION'],
    ),
    'delivery challan': _baseData(
      kind: UltraBillKind.deliveryChallan,
      documentTitle: 'DELIVERY CHALLAN',
      copyLabels: const ['ORIGINAL DELIVERY CHALLAN'],
    ),
  };

  for (final entry in cases.entries) {
    test('${entry.key} PDF generates without layout assertion', () async {
      final bytes = await buildUltraInvoicePdf(entry.value);
      expect(bytes.isNotEmpty, isTrue);
    });
  }
}
