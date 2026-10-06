import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_enterprise/widgets/invoice.dart';

void main() {
  test('purchase order PDF includes tax totals and terms', () async {
    final data = InvoiceData(
      kind: UltraBillKind.purchaseOrder,
      invoiceNo: 'PO-2026-8621D8',
      date: '06-10-2026',
      dispatch: 'Road',
      consigneeName: 'test supplier',
      consigneeAddress: '2 test road, chennai, 600001',
      gstin: '33BBBBB0000B1Z5',
      mobile: '1234567892',
      items: const [
        InvoiceItem(
          description: 'final test product',
          hsnCode: '8471',
          qty: 20,
          price: 100,
        ),
      ],
      amountInWords: formatUltraAmountInWords(2410),
      bankName: 'STATE BANK OF INDIA',
      accountNo: '123456789',
      ifscCode: 'SBIN0001234',
      bankAddress: 'SINGASANDRA',
      documentTitle: 'PURCHASE ORDER',
      partySectionTitle: 'NAME & ADDRESS OF SUPPLIER',
      copyLabels: ultraPurchaseOrderCopyLabels,
      forwardingLabel: 'Estimated Freight',
      totalGrandLabel: 'Total Value',
      pAndF: 50,
      cgstAmountOverride: 180,
      sgstAmountOverride: 180,
      grandTotalOverride: 2410,
      cgstPercent: 9,
      sgstPercent: 9,
    );

    final bytes = await buildUltraInvoicePdf(data);
    expect(bytes.isNotEmpty, isTrue);

    final path = '/tmp/po_smoke_test.pdf';
    await File(path).writeAsBytes(bytes);
    expect(bytes.length, greaterThan(30000), reason: 'PDF unexpectedly small');
  });
}
