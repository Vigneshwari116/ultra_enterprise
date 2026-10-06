import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'pdf_document_layout_test.dart' as samples;
import 'package:ultra_enterprise/widgets/invoice.dart';

void main() {
  test('generate sample PDFs for visual review', () async {
    final outDir = Directory('/opt/cursor/artifacts/pdfs');
    outDir.createSync(recursive: true);
    final docs = <String, InvoiceData>{
      'tax_invoice': samples.taxInvoiceSample(),
      'purchase_order': samples.purchaseOrderSample(),
      'purchase_voucher': samples.purchaseVoucherSample(),
      'quotation': samples.quotationSample(),
      'delivery_challan': samples.deliveryChallanSample(),
      'credit_note': samples.creditNoteSample(),
      'debit_note': samples.debitNoteSample(),
    };
    for (final e in docs.entries) {
      final bytes = await buildUltraInvoicePdf(e.value);
      final path = '${outDir.path}/${e.key}.pdf';
      await File(path).writeAsBytes(bytes);
      expect(samples.pdfPageCount(bytes), e.value.copyLabels.length);
    }
  });
}
