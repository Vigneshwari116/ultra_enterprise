import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_enterprise/widgets/invoice.dart';

import 'bill_format_pdf_smoke_test.dart';
import 'pdf_document_layout_test.dart' as samples;

void main() {
  test('generate sample PDFs for visual review', () async {
    final outDir = Directory('build/sample_pdfs');
    outDir.createSync(recursive: true);
    final docs = <String, InvoiceData>{
      'normal_bill': _normalBillStress(),
      'labour_bill': _labourBillStress(),
      'proforma': _proformaStress(),
      'dc_inward': _dcStress(inward: true),
      'dc_outward': _dcStress(inward: false),
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
