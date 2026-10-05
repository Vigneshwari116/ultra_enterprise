import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'invoice.dart';

/// In-app A4 PDF preview with system print and share actions.
class InvoicePdfPreviewScreen extends StatelessWidget {
  const InvoicePdfPreviewScreen({
    super.key,
    required this.bytes,
    required this.filename,
  });

  final Uint8List bytes;
  final String filename;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(filename, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => Printing.layoutPdf(onLayout: (_) async => bytes),
          ),
          IconButton(
            tooltip: 'Share / Save PDF',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => Printing.sharePdf(bytes: bytes, filename: filename),
          ),
        ],
      ),
      body: PdfPreview(
        maxPageWidth: 700,
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: filename,
        build: (_) async => bytes,
      ),
    );
  }
}

Future<void> printUltraInvoice(BuildContext context, InvoiceData data) async {
  final bytes = await buildUltraInvoicePdf(data);
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => InvoicePdfPreviewScreen(
        bytes: bytes,
        filename: '${data.invoiceNo}.pdf',
      ),
    ),
  );
}

Future<void> layoutPrintUltraInvoice(BuildContext context, InvoiceData data) async {
  final bytes = await buildUltraInvoicePdf(data);
  await Printing.layoutPdf(onLayout: (_) async => bytes);
}

Future<void> shareUltraInvoicePdf(BuildContext context, InvoiceData data, {String? filename}) async {
  final bytes = await buildUltraInvoicePdf(data);
  await Printing.sharePdf(bytes: bytes, filename: filename ?? '${data.invoiceNo}.pdf');
}
