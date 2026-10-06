import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_enterprise/widgets/adjustment_note_document.dart';
import 'package:ultra_enterprise/widgets/delivery_challan_document.dart';
import 'package:ultra_enterprise/widgets/invoice.dart';
import 'package:ultra_enterprise/widgets/purchase_order_document.dart';
import 'package:ultra_enterprise/widgets/purchase_voucher_document.dart';
import 'package:ultra_enterprise/widgets/quotation_document.dart';
import 'package:ultra_enterprise/widgets/sales_report.dart';

/// PDF streams are Flate-compressed; count pages from the document catalog.
int pdfPageCount(Uint8List bytes) {
  final text = String.fromCharCodes(bytes);
  final countMatch = RegExp(r'/Type\s*/Pages[^>]*?/Count\s+(\d+)').firstMatch(text);
  if (countMatch != null) return int.parse(countMatch.group(1)!);
  return '/Type /Page'.allMatches(text).length;
}

InvoiceItem _sampleItem({String remarks = ''}) => InvoiceItem(
      description: 'Sample product',
      hsnCode: '8471',
      qty: 10,
      price: 100,
      remarks: remarks,
    );

InvoiceData taxInvoiceSample() => InvoiceData(
      kind: UltraBillKind.taxInvoice,
      documentTitle: 'TAX INVOICE',
      invoiceNo: 'INV-2026-TEST',
      date: '07-04-2026',
      dispatch: 'KA50B2331',
      consigneeName: 'Test Customer',
      consigneeAddress: 'Test Address',
      gstin: '29AACCC5171H1ZM',
      items: [_sampleItem()],
      amountInWords: 'ONE THOUSAND ONE HUNDRED EIGHTY RUPEES ONLY',
      bankName: 'STATE BANK OF INDIA',
      accountNo: '54009859972',
      ifscCode: 'SBIN0040552',
      bankAddress: 'SINGASANDRA',
      pAndF: 50,
      cgstAmountOverride: 90,
      sgstAmountOverride: 90,
      igstAmountOverride: 0,
      grandTotalOverride: 1180,
      leftSignatureLabel: 'Receiver signature & Seal',
    );

InvoiceData purchaseOrderSample() => InvoiceData(
      kind: UltraBillKind.purchaseOrder,
      documentTitle: 'PURCHASE ORDER',
      partySectionTitle: 'NAME & ADDRESS OF SUPPLIER',
      copyLabels: ultraPurchaseOrderCopyLabels,
      invoiceNo: 'PO-2026-TEST',
      date: '06-10-2026',
      dispatch: 'Road',
      consigneeName: 'Test Supplier',
      consigneeAddress: 'Chennai',
      gstin: '33BBBBB0000B1Z6',
      items: [_sampleItem()],
      pAndF: 100,
      forwardingLabel: 'Estimated Freight',
      totalGrandLabel: 'Total Value',
      cgstAmountOverride: 90,
      sgstAmountOverride: 90,
      igstAmountOverride: 0,
      grandTotalOverride: 1280,
      amountInWords: 'ONE THOUSAND TWO HUNDRED EIGHTY RUPEES ONLY',
      bankName: 'STATE BANK OF INDIA',
      accountNo: '54009859972',
      ifscCode: 'SBIN0040552',
      bankAddress: 'SINGASANDRA',
    );

InvoiceData purchaseVoucherSample() => InvoiceData(
      kind: UltraBillKind.purchaseVoucher,
      documentTitle: 'PURCHASE VOUCHER',
      partySectionTitle: 'NAME & ADDRESS OF SUPPLIER',
      copyLabels: ultraOriginalDuplicateLabels(
        'PURCHASE VOUCHER',
        duplicateLabel: 'DUPLICATE PURCHASE VOUCHER COPY',
      ),
      invoiceNo: 'PV-2026-TEST',
      date: '06-10-2026',
      dispatch: '',
      consigneeName: 'Test Supplier',
      consigneeAddress: 'Chennai',
      gstin: '33BBBBB0000B1Z6',
      items: [_sampleItem()],
      cgstAmountOverride: 90,
      sgstAmountOverride: 90,
      igstAmountOverride: 0,
      grandTotalOverride: 1180,
      totalGrandLabel: 'Total Value',
      amountInWords: 'ONE THOUSAND ONE HUNDRED EIGHTY RUPEES ONLY',
      bankName: 'STATE BANK OF INDIA',
      accountNo: '54009859972',
      ifscCode: 'SBIN0040552',
      bankAddress: 'SINGASANDRA',
    );

InvoiceData quotationSample() => InvoiceData(
      kind: UltraBillKind.quotation,
      documentTitle: 'QUOTATION',
      partySectionTitle: 'CUSTOMER / PARTY DETAILS',
      copyLabels: ultraOriginalDuplicateLabels('QUOTATION'),
      invoiceNo: '1',
      date: '2026-08-12',
      dispatch: 'vijay',
      ewbNo: '10 DAYS',
      consigneeName: 'Test Party',
      consigneeAddress: 'Chennai',
      gstin: '33AADCS1638L1ZB',
      items: [
        InvoiceItem(
          description: 'endurance machine',
          hsnCode: '',
          qty: 1,
          price: 45000,
        ),
      ],
      pAndF: 0,
      grandTotalOverride: 45000,
      amountInWords: 'FORTY FIVE THOUSAND RUPEES ONLY',
      bankName: 'STATE BANK OF INDIA',
      accountNo: '54009859972',
      ifscCode: 'SBIN0040552',
      bankAddress: 'SINGASANDRA',
      preambleLines: const ['Dear Sir,', 'Sub: Quotation for cable endurance'],
      customTerms: const [
        '.Delivery Period: Within 60 days from PO confirmation.',
        '.GST: GST will be charged extra as applicable.',
      ],
      leftSignatureLabel: 'Prepared By',
      forwardingLabel: 'Forwarding',
      totalGrandLabel: 'Total Cost',
      showBankInTotals: false,
    );

InvoiceData deliveryChallanSample() => InvoiceData(
      kind: UltraBillKind.deliveryChallan,
      documentTitle: 'DELIVERY CHALLAN',
      partySectionTitle: 'NAME & ADDRESS OF RECEIVER',
      copyLabels: const [
        'ORIGINAL DELIVERY CHALLAN',
        'DUPLICATE DC INWARD LABELS',
      ],
      invoiceNo: 'DC-2026-TEST',
      date: '04-07-2026',
      custPo: '123',
      poDate: '04-07-2026',
      dispatch: '45ty678990',
      ewbNo: '67777',
      consigneeName: 'Test Receiver',
      consigneeAddress: 'Bengaluru',
      gstin: '29ADHPN6794L1ZL',
      mobile: 'NOT AVAILABLE',
      items: [_sampleItem(remarks: 'Handle with care')],
      pAndF: 0,
      grandTotalOverride: 1000,
      amountInWords: 'ONE THOUSAND RUPEES ONLY',
      bankName: 'STATE BANK OF INDIA',
      accountNo: '54009859972',
      ifscCode: 'SBIN0040552',
      bankAddress: 'SINGASANDRA',
      forwardingLabel: 'Forwarding',
      totalGrandLabel: 'Total Value',
    );

InvoiceData creditNoteSample() => InvoiceData(
      kind: UltraBillKind.creditNote,
      documentTitle: 'CREDIT NOTE / SALES REVERSAL',
      partySectionTitle: 'NAME & ADDRESS OF CUSTOMER (CREDITED)',
      copyLabels: ultraOriginalDuplicateLabels(
        'CREDIT NOTE / SALES REVERSAL',
        duplicateLabel: 'DUPLICATE CLIENT REVERSAL COPY',
      ),
      invoiceNo: 'CN-2026-TEST',
      date: '2026-07-01',
      origInvNo: '203',
      origInvDate: '2025-11-25',
      reason: 'SALES RETURN',
      dispatch: '',
      consigneeName: 'Test Customer',
      consigneeAddress: 'Bengaluru',
      gstin: '29ABCCS9740F1Z1',
      items: [_sampleItem()],
      cgstAmountOverride: 1350,
      sgstAmountOverride: 1350,
      igstAmountOverride: 0,
      grandTotalOverride: 17700,
      totalGrandLabel: 'Total Value',
      amountInWords: 'SEVENTEEN THOUSAND SEVEN HUNDRED RUPEES ONLY',
      bankName: 'STATE BANK OF INDIA',
      accountNo: '54009859972',
      ifscCode: 'SBIN0040552',
      bankAddress: 'SINGASANDRA',
    );

InvoiceData debitNoteSample() => InvoiceData(
      kind: UltraBillKind.debitNote,
      documentTitle: 'DEBIT NOTE / PURCHASE REVERSAL',
      partySectionTitle: 'NAME & ADDRESS OF SUPPLIER (DEBITED)',
      copyLabels: ultraOriginalDuplicateLabels(
        'DEBIT NOTE / PURCHASE REVERSAL',
        duplicateLabel: 'DUPLICATE SUPPLIER REVERSAL COPY',
      ),
      invoiceNo: 'DN-2026-TEST',
      date: '2026-07-01',
      origInvNo: 'PV-100',
      origInvDate: '2025-11-25',
      reason: 'PURCHASE RETURN',
      dispatch: '',
      consigneeName: 'Test Supplier',
      consigneeAddress: 'Chennai',
      gstin: '33BBBBB0000B1Z6',
      items: [_sampleItem()],
      cgstAmountOverride: 900,
      sgstAmountOverride: 900,
      igstAmountOverride: 0,
      grandTotalOverride: 11800,
      totalGrandLabel: 'Total Value',
      amountInWords: 'ELEVEN THOUSAND EIGHT HUNDRED RUPEES ONLY',
      bankName: 'STATE BANK OF INDIA',
      accountNo: '54009859972',
      ifscCode: 'SBIN0040552',
      bankAddress: 'SINGASANDRA',
    );

void main() {
  test('tax invoice PDF builds with 5 copy pages', () async {
    final data = taxInvoiceSample();
    expect(data.copyLabels.length, 5);
    expect(data.kind, UltraBillKind.taxInvoice);
    final bytes = await buildUltraInvoicePdf(data);
    expect(bytes, isNotEmpty);
    expect(pdfPageCount(bytes), 5);
  });

  test('purchase order PDF builds with PO copy labels', () async {
    final data = purchaseOrderSample();
    expect(data.kind, UltraBillKind.purchaseOrder);
    expect(data.forwardingLabel, 'Estimated Freight');
    expect(data.copyLabels, contains('ORIGINAL PURCHASE ORDER'));
    final bytes = await buildUltraInvoicePdf(data);
    expect(bytes, isNotEmpty);
    expect(pdfPageCount(bytes), data.copyLabels.length);
  });

  test('purchase voucher PDF builds without freight totals mode', () async {
    final data = purchaseVoucherSample();
    expect(data.kind, UltraBillKind.purchaseVoucher);
    expect(data.documentTitle, 'PURCHASE VOUCHER');
    final bytes = await buildUltraInvoicePdf(data);
    expect(bytes, isNotEmpty);
    expect(pdfPageCount(bytes), data.copyLabels.length);
  });

  test('quotation PDF builds with custom terms and Prepared By label', () async {
    final data = quotationSample();
    expect(data.kind, UltraBillKind.quotation);
    expect(data.customTerms, isNotNull);
    expect(data.leftSignatureLabel, 'Prepared By');
    expect(data.showBankInTotals, isFalse);
    final bytes = await buildUltraInvoicePdf(data);
    expect(bytes, isNotEmpty);
    expect(pdfPageCount(bytes), data.copyLabels.length);
  });

  test('delivery challan PDF builds with remarks on line items', () async {
    final data = deliveryChallanSample();
    expect(data.kind, UltraBillKind.deliveryChallan);
    expect(data.items.first.remarks, isNotEmpty);
    final bytes = await buildUltraInvoicePdf(data);
    expect(bytes, isNotEmpty);
    expect(pdfPageCount(bytes), data.copyLabels.length);
  });

  test('credit note PDF builds with reversal metadata fields', () async {
    final data = creditNoteSample();
    expect(data.kind, UltraBillKind.creditNote);
    expect(data.origInvNo, isNotEmpty);
    expect(data.reason, isNotEmpty);
    final bytes = await buildUltraInvoicePdf(data);
    expect(bytes, isNotEmpty);
    expect(pdfPageCount(bytes), data.copyLabels.length);
  });

  test('debit note PDF builds with purchase reversal title', () async {
    final data = debitNoteSample();
    expect(data.kind, UltraBillKind.debitNote);
    expect(data.documentTitle, 'DEBIT NOTE / PURCHASE REVERSAL');
    final bytes = await buildUltraInvoicePdf(data);
    expect(bytes, isNotEmpty);
    expect(pdfPageCount(bytes), data.copyLabels.length);
  });

  test('all document kinds build non-empty PDFs', () async {
    for (final builder in [
      taxInvoiceSample,
      purchaseOrderSample,
      purchaseVoucherSample,
      quotationSample,
      deliveryChallanSample,
      creditNoteSample,
      debitNoteSample,
    ]) {
      final data = builder();
      final bytes = await buildUltraInvoicePdf(data);
      expect(bytes.length, greaterThan(1000));
      expect(pdfPageCount(bytes), data.copyLabels.length);
    }
  });

  test('document-specific reprint entry points are wired', () {
    expect(reprintQuotation, isA<Function>());
    expect(reprintDeliveryChallan, isA<Function>());
    expect(reprintAdjustmentNote, isA<Function>());
    expect(reprintPurchaseOrder, isA<Function>());
    expect(reprintPurchaseVoucher, isA<Function>());
    expect(reprintSalesInvoice, isA<Function>());
    expect(quotationInvoiceData, isA<Function>());
    expect(deliveryChallanInvoiceData, isA<Function>());
    expect(adjustmentNoteInvoiceData, isA<Function>());
    expect(purchaseOrderDataFromId, isA<Function>());
    expect(purchaseVoucherInvoiceData, isA<Function>());
    expect(invoiceDataFromId, isA<Function>());
  });
}
