import 'dart:io';

import 'package:ultra_enterprise/models/company_settings.dart';
import 'package:ultra_enterprise/widgets/invoice.dart';

Future<void> main() async {
  final company = CompanySettings.withDefaults();
  final data = InvoiceData(
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
    items: const [
      InvoiceItem(description: 'SAFTY  GUARD  CEMENTS  GREY', hsnCode: '23230', qty: 100, price: 240),
    ],
    cgstPercent: 9,
    sgstPercent: 9,
    igstPercent: 18,
    cgstAmountOverride: 2160,
    sgstAmountOverride: 2160,
    grandTotalOverride: 28320,
    amountInWords: formatUltraAmountInWords(28320),
    bankName: 'STATE BANK OF INDIA',
    accountNo: '54009859972',
    ifscCode: 'SBIN0040552',
    bankAddress: 'SINGASANDRA',
    company: company,
  );
  final bytes = await buildUltraInvoicePdf(data);
  await File('/tmp/ultra_app_page1.pdf').writeAsBytes(bytes);
}
