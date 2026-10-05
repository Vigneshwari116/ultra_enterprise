import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_enterprise/models/company_settings.dart';
import 'package:ultra_enterprise/widgets/invoice.dart';

Future<String> _extractPdfText(List<int> bytes) async {
  final path = '${Directory.systemTemp.path}/ultra_invoice_test.pdf';
  await File(path).writeAsBytes(bytes);
  final result = await Process.run('python3', [
    '-c',
    '''
import sys
from pypdf import PdfReader
r = PdfReader(sys.argv[1])
for i, p in enumerate(r.pages):
    print(f"--- page {i+1} ---")
    print((p.extract_text() or "").strip())
''',
    path,
  ]);
  return result.stdout as String? ?? '';
}

CompanySettings _referenceCompany() => const CompanySettings(
      companyName: 'ULTRA ENGINEERING WORKS',
      tagline: 'SPM MANUFACTURERS & FABRICATORS',
      officeAddress:
          'OFFICE:NO: 15/6, 5th CROSS, VIDYA NAGAR, OPP. S.K.F. FACTORY, BOMMASANDRA INDL. AREA, BENGALURU-560 099.',
      worksAddress:
          'No.B-48, KSSIDC INDL Estate, Near Karnataka Bank, Bommasandra Indl. Area, BENGALURU-560 099.',
      teleFax: '080-27834287',
      mobile: '9342509313',
      gstin: '29AHOPK6473G1ZS',
      serviceTaxNo: 'AHOPK6473GSD001',
      bankName: 'STATE BANK OF INDIA',
      bankAccountNo: '54009859972',
      ifscCode: 'SBIN0040552',
      branch: 'SINGASANDRA',
    );

InvoiceData _referenceInvoice() {
  const item = InvoiceItem(
    description: 'SAFTY GUARD CEMENTS GREY',
    hsnCode: '23230',
    qty: 100,
    price: 240,
  );
  return InvoiceData(
    invoiceNo: '1',
    date: '09/23/2026',
    dispatch: '',
    consigneeName: 'ADYAR ANANDA BHAVAN SWEETS INDIA PVT. LTD.',
    consigneeAddress: '#65/1, TO 65/4, GUDDAHATTI ROAD, NERALUR POST, ATTIBELI HOBLI, ANEKAL TALUK, BANGALORE 562 107',
    gstin: '29AHOPK6473G1ZS',
    mobile: '29420606516',
    shippingBlock: 'ADYAR ANANDA BHAVAN SWEETS INDIA PVT. LTD.',
    items: [item],
    cgstPercent: 9,
    sgstPercent: 9,
    igstPercent: 0,
    pAndF: 0,
    cgstAmountOverride: 2160,
    sgstAmountOverride: 2160,
    grandTotalOverride: 28320,
    amountInWords: formatUltraAmountInWords(28320),
    bankName: 'STATE BANK OF INDIA',
    accountNo: '54009859972',
    ifscCode: 'SBIN0040552',
    bankAddress: 'SINGASANDRA',
    company: _referenceCompany(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy Expanded layout drops table/footer text', () async {
    final data = _referenceInvoice();
    final legacy = await buildUltraInvoicePdfLegacyExpanded(data);
    final legacyText = await _extractPdfText(legacy);
    expect(legacyText.contains('HSN/SAC'), isFalse);
    expect(legacyText.contains('G.Total'), isFalse);
    expect(legacyText.contains('TERMS & CONDITIONS'), isFalse);
  });

  test('fixed-height layout includes full invoice body on every copy page', () async {
    final data = _referenceInvoice();
    final bytes = await buildUltraInvoicePdf(data);
    final text = await _extractPdfText(bytes);
    for (final marker in [
      'DESCRIPTION',
      'HSN/SAC',
      'PRICE/UN',
      'AMOUNT',
      'G.Total',
      'TERMS & CONDITIONS',
      'Authorised Signatory',
      'ORIGINAL FOR BUYER',
      'DUPLICATE FOR TRANSPORTER',
      '28320.00',
      '24000.00',
      '23230',
    ]) {
      expect(text.contains(marker), isTrue, reason: 'missing $marker');
    }

    expect(text.split('--- page').length - 1, 5);
  });

  test('other document kinds render table and footer', () async {
    final company = _referenceCompany();
    final item = const InvoiceItem(description: 'Widget', hsnCode: '1001', qty: 2, price: 50);
    final kinds = <InvoiceData>[
      InvoiceData(
        kind: UltraBillKind.deliveryChallan,
        documentTitle: 'DELIVERY CHALLAN',
        copyLabels: const ['DUPLICATE DELIVERY CHALLAN'],
        invoiceNo: 'DC-1',
        date: '01/15/2026',
        dispatch: 'Road',
        consigneeName: 'Party',
        consigneeAddress: 'Addr',
        gstin: '',
        items: [item],
        amountInWords: formatUltraAmountInWords(100),
        bankName: company.bankName,
        accountNo: company.bankAccountNo,
        ifscCode: company.ifscCode,
        bankAddress: company.branch,
        company: company,
        grandTotalOverride: 100,
      ),
      InvoiceData(
        kind: UltraBillKind.quotation,
        documentTitle: 'QUOTATION',
        copyLabels: const ['DUPLICATE QUOTATION REPRINT'],
        invoiceNo: 'QT-1',
        date: '01/15/2026',
        dispatch: 'Ref',
        consigneeName: 'Party',
        consigneeAddress: 'Addr',
        gstin: '',
        items: [item],
        amountInWords: formatUltraAmountInWords(100),
        bankName: company.bankName,
        accountNo: company.bankAccountNo,
        ifscCode: company.ifscCode,
        bankAddress: company.branch,
        company: company,
        grandTotalOverride: 100,
      ),
      InvoiceData(
        kind: UltraBillKind.purchaseOrder,
        documentTitle: 'PURCHASE ORDER',
        copyLabels: const ['ORIGINAL FOR SUPPLIER'],
        invoiceNo: 'PO-1',
        date: '01/15/2026',
        dispatch: 'Courier',
        consigneeName: 'Supplier',
        consigneeAddress: 'Addr',
        gstin: '',
        items: [item],
        amountInWords: formatUltraAmountInWords(100),
        bankName: company.bankName,
        accountNo: company.bankAccountNo,
        ifscCode: company.ifscCode,
        bankAddress: company.branch,
        company: company,
        grandTotalOverride: 100,
      ),
      InvoiceData(
        kind: UltraBillKind.purchaseVoucher,
        documentTitle: 'PURCHASE VOUCHER',
        copyLabels: const ['ORIGINAL FOR SUPPLIER'],
        invoiceNo: 'PV-1',
        date: '01/15/2026',
        dispatch: '',
        consigneeName: 'Supplier',
        consigneeAddress: 'Addr',
        gstin: '',
        items: [item],
        amountInWords: formatUltraAmountInWords(100),
        bankName: company.bankName,
        accountNo: company.bankAccountNo,
        ifscCode: company.ifscCode,
        bankAddress: company.branch,
        company: company,
        grandTotalOverride: 100,
      ),
      InvoiceData(
        kind: UltraBillKind.creditNote,
        documentTitle: 'CREDIT NOTE / SALES REVERSAL',
        copyLabels: const ['DUPLICATE CLIENT REVERSAL COPY'],
        invoiceNo: 'CN-1',
        date: '01/15/2026',
        dispatch: '',
        consigneeName: 'Customer',
        consigneeAddress: 'Addr',
        gstin: '',
        items: [item],
        amountInWords: formatUltraAmountInWords(100),
        bankName: company.bankName,
        accountNo: company.bankAccountNo,
        ifscCode: company.ifscCode,
        bankAddress: company.branch,
        company: company,
        grandTotalOverride: 100,
      ),
    ];

    for (final data in kinds) {
      final bytes = await buildUltraInvoicePdf(data);
      final text = await _extractPdfText(bytes);
      expect(text.contains('DESCRIPTION'), isTrue, reason: data.documentTitle);
      expect(text.contains('TERMS & CONDITIONS'), isTrue, reason: data.documentTitle);
      expect(text.contains('Authorised Signatory'), isTrue, reason: data.documentTitle);
    }
  });
}
