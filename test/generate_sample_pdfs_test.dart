import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_enterprise/widgets/invoice.dart';

import 'pdf_document_layout_test.dart' as samples;
import 'support/bill_sample_data.dart';

void main() {
  test('generate sample PDFs for visual review', () async {
    final outDir = Directory('build/sample_pdfs');
    outDir.createSync(recursive: true);
    final docs = <String, InvoiceData>{
      'normal_bill': normalBillSample(),
      'labour_bill': labourBillSample(),
      'proforma': proformaSample(),
      'dc_inward': dcSample(inward: true),
      'dc_outward': dcSample(inward: false),
    };
    for (final e in docs.entries) {
      final bytes = await buildUltraInvoicePdf(e.value);
      final path = '${outDir.path}/${e.key}.pdf';
      await File(path).writeAsBytes(bytes);
      expect(samples.pdfPageCount(bytes), 1);
    }
    // ignore: avoid_print
    print(outDir.absolute.path);
  });
}
