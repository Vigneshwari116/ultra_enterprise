import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_enterprise/widgets/invoice.dart';

import 'pdf_document_layout_test.dart';
import 'support/bill_sample_data.dart';

void main() {
  final cases = <String, InvoiceData>{
    'normal bill': normalBillSample(),
    'labour bill': labourBillSample(),
    'proforma': proformaSample(),
    'DC inward': dcSample(inward: true),
    'DC outward': dcSample(inward: false),
  };

  for (final entry in cases.entries) {
    test('${entry.key} PDF builds one page without layout exception', () async {
      final bytes = await buildUltraInvoicePdf(entry.value);
      expect(bytes, isNotEmpty);
      expect(pdfPageCount(bytes), 1);
    });
  }
}
