import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_enterprise/widgets/invoice.dart';

import 'pdf_document_layout_test.dart';
import 'support/bill_sample_data.dart';

void main() {
  final cases = <String, InvoiceData>{
    'normal bill': normalBillSample(),
    'labour bill': labourBillSample(),
    'proforma': proformaSample(),
    'purchase order': purchaseOrderPdfSample(),
    'purchase voucher': purchaseVoucherPdfSample(),
    'DC inward': dcSample(inward: true),
    'DC outward': dcSample(inward: false),
  };

  const fiveCopyNames = {
    'normal bill',
    'labour bill',
    'proforma',
    'purchase order',
    'purchase voucher',
  };

  for (final entry in cases.entries) {
    test('${entry.key} PDF builds without layout exception', () async {
      final bytes = await buildUltraInvoicePdf(entry.value);
      expect(bytes, isNotEmpty);
      if (fiveCopyNames.contains(entry.key)) {
        expect(pdfPageCount(bytes), 5);
        const rest = [
          'DUPLICATE FOR TRANSPORTER',
          'TRIPLICATE FOR SUPPLIER',
          'COPY FOR ACCOUNTS',
          'EXTRA COPY',
        ];
        final buyerCopy = entry.key == 'normal bill' ||
            entry.key == 'labour bill' ||
            entry.key == 'proforma';
        expect(
          entry.value.copyLabels,
          [
            buyerCopy ? 'ORIGINAL FOR BUYER' : 'ORIGINAL FOR RECIPIENT',
            ...rest,
          ],
        );
      } else {
        expect(pdfPageCount(bytes), 1);
      }
    });
  }
}
