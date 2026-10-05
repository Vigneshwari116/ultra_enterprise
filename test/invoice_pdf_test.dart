import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_enterprise/config/company_settings_defaults.dart';
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

CompanySettings _referenceCompany() => CompanySettings.withDefaults();

InvoiceData _referenceInvoice() {
  const item = InvoiceItem(
    description: 'SAFTY  GUARD  CEMENTS  GREY',
    hsnCode: '23230',
    qty: 100,
    price: 240,
  );
  return InvoiceData(
    invoiceNo: '1',
    date: '09/23/2026',
    dispatch: '',
    consigneeName: 'ADYAR ANANDA BHAVAN SWEETS INDIA PVT. LTD.',
    consigneeAddress: '#65/1, TO 65/4, GUDDAHATTI ROAD, NERALUR POST, ATTIBELI HOBLI, ANEKAL TALUK,',
    consigneeCity: 'BANGALORE',
    consigneePincode: '562 107',
    gstin: '29AHOPK6473G1ZS',
    mobile: '29420606516',
    shippingBlock: 'ADYAR ANANDA BHAVAN SWEETS INDIA PVT. LTD.',
    items: [item],
    cgstPercent: 9,
    sgstPercent: 9,
    igstPercent: 18,
    pAndF: 0,
    roundOff: 0,
    cgstAmountOverride: 2160,
    sgstAmountOverride: 2160,
    igstAmountOverride: 0,
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

  test('reference totals and comma amounts', () async {
    final data = _referenceInvoice();
    final bytes = await buildUltraInvoicePdf(data);
    final text = await _extractPdfText(bytes);
    expect(text.contains('24,000.00'), isTrue);
    expect(text.contains('2,160.00'), isTrue);
    expect(text.contains('28,320.00'), isTrue);
    expect(text.contains('ORIGINAL FOR BUYER'), isTrue);
    expect(text.contains('Karnataka Bank'), isTrue);
    for (final bad in [
      'KarnatakaBank',
      'Reponsebility',
      'Judrisdiction',
      'inthe',
      'Good once',
      'A\\c',
      'CONSIGNE\n',
    ]) {
      expect(text.contains(bad), isFalse, reason: 'found typo $bad');
    }
    expect(text.contains('Goods once sold'), isTrue);
    expect(text.contains('CONSIGNEE'), isTrue);
  });

  test('25 items paginate with footer on last page only per copy', () async {
    final items = List.generate(
      25,
      (i) => InvoiceItem(description: 'Item $i', hsnCode: '1000', qty: 1, price: 10.0 + i),
    );
    final data = _referenceInvoice().copyWithItems(items);
    final bytes = await buildUltraInvoicePdf(data);
    final text = await _extractPdfText(bytes);
    expect(text.split('--- page').length - 1, greaterThanOrEqualTo(10));
    expect(text.contains('G.Total'), isTrue);
  });

  test('bank snapshot appears when set on document row', () async {
    final data = _referenceInvoice();
    final withBank = InvoiceData(
      invoiceNo: data.invoiceNo,
      date: data.date,
      dispatch: data.dispatch,
      consigneeName: data.consigneeName,
      consigneeAddress: data.consigneeAddress,
      consigneeCity: data.consigneeCity,
      consigneePincode: data.consigneePincode,
      gstin: data.gstin,
      mobile: data.mobile,
      shippingBlock: data.shippingBlock,
      items: data.items,
      amountInWords: data.amountInWords,
      bankName: 'CUSTOM BANK LTD',
      accountNo: data.accountNo,
      ifscCode: data.ifscCode,
      bankAddress: data.bankAddress,
      company: data.company,
      cgstPercent: data.cgstPercent,
      sgstPercent: data.sgstPercent,
      igstPercent: data.igstPercent,
      cgstAmountOverride: data.cgstAmountOverride,
      sgstAmountOverride: data.sgstAmountOverride,
      grandTotalOverride: data.grandTotalOverride,
    );
    final text = await _extractPdfText(await buildUltraInvoicePdf(withBank));
    expect(text.contains('CUSTOM BANK LTD'), isTrue);
  });
}

extension on InvoiceData {
  InvoiceData copyWithItems(List<InvoiceItem> items) => InvoiceData(
        invoiceNo: invoiceNo,
        date: date,
        dispatch: dispatch,
        consigneeName: consigneeName,
        consigneeAddress: consigneeAddress,
        consigneeCity: consigneeCity,
        consigneePincode: consigneePincode,
        gstin: gstin,
        mobile: mobile,
        shippingBlock: shippingBlock,
        items: items,
        amountInWords: formatUltraAmountInWords(grandTotal),
        bankName: bankName,
        accountNo: accountNo,
        ifscCode: ifscCode,
        bankAddress: bankAddress,
        company: company,
        cgstPercent: cgstPercent,
        sgstPercent: sgstPercent,
        igstPercent: igstPercent,
        cgstAmountOverride: cgstAmountOverride,
        sgstAmountOverride: sgstAmountOverride,
        grandTotalOverride: null,
      );
}
