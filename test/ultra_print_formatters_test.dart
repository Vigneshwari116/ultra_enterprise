import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_enterprise/widgets/invoice.dart';
import 'package:ultra_enterprise/widgets/ultra_print_helpers.dart';

import 'support/bill_sample_data.dart';

void main() {
  test('formatUltraBillDateShort', () {
    expect(formatUltraBillDateShort('2026-10-12'), '12-Oct-26');
  });

  test('formatUltraMoney uses thousands separators', () {
    expect(formatUltraMoney(14580), '14,580.00');
    expect(formatUltraMoney(14580.4), '14,580.40');
  });

  test('print PDF file names use plain numbers', () {
    expect(ultraPrintPdfFileNameInvoice('209'), 'Invoice-209');
    expect(ultraPrintPdfFileNameInvoice('SAL-209'), 'Invoice-209');
    expect(ultraPrintPdfFileNameDc('338'), 'DC-338');
    expect(ultraPlainDocumentNumber('DC-2026-338'), '338');
  });

  test('pdfLatin1 replaces em dash and drops non-Latin-1', () {
    expect(pdfLatin1('empty\u2014field'), 'empty-field');
    expect(pdfLatin1('plain ASCII'), 'plain ASCII');
  });

  test('taxPercentsFromTotals uses stored amounts not fixed 9/9/18', () {
    final intra = taxPercentsFromTotals(
      taxable: 1000,
      cgst: 90,
      sgst: 90,
      igst: 0,
    );
    expect(intra.cgst, closeTo(9, 0.01));
    expect(intra.sgst, closeTo(9, 0.01));
    expect(intra.igst, closeTo(0, 0.01));

    final inter = taxPercentsFromTotals(
      taxable: 184,
      cgst: 0,
      sgst: 0,
      igst: 33.12,
    );
    expect(inter.cgst, closeTo(0, 0.01));
    expect(inter.sgst, closeTo(0, 0.01));
    expect(inter.igst, closeTo(18, 0.01));
  });

  test('bill quantity keeps two decimals and DC quantity stays whole', () {
    expect(formatBillQuantity(3), '3.00');
    expect(formatBillQuantity(900), '900.00');
    expect(formatPrintQuantity(3), '3');
    expect(formatPrintQuantity(900), '900');
  });

  test('labour SEL DC is the customer challan and UEW DC is sel_dc_no', () {
    final fields = labourDcPrintFields(
      selDcNo: '299',
      selDcDate: '2026-09-25',
      challanNo: '927000483',
      challanDate: '2026-09-28',
    );
    expect(fields.selDcNo, '927000483');
    expect(fields.selDcDate, '25 September 2026');
    expect(fields.uewDcNo, '299');
    expect(fields.uewDcDate, '28/09/2026');

    final sample = labourBillSample();
    expect(sample.selDcNo, '927000483');
    expect(sample.selDcDate, '25 September 2026');
    expect(sample.dcNo, '299');
    expect(sample.dcDate, '28/09/2026');
  });

  test('printed G.Total is taxable plus taxes for normal, labour and proforma', () {
    final normal = normalBillSample();
    final labour = labourBillSample();
    final proforma = proformaSample();
    expect(normal.lineGrandTotal, closeTo(31010.40, 0.001));
    expect(labour.lineGrandTotal, closeTo(15292.80, 0.001));
    expect(proforma.lineGrandTotal, closeTo(31010.40, 0.001));
    expect(formatUltraAmountInWords(normal.lineGrandTotal),
        'THIRTY ONE THOUSAND TEN ONLY');
    expect(formatUltraAmountInWords(labour.lineGrandTotal),
        'FIFTEEN THOUSAND TWO HUNDRED AND NINETY THREE ONLY');
    expect(formatUltraAmountInWords(proforma.lineGrandTotal),
        'THIRTY ONE THOUSAND TEN ONLY');

    final wrongStored = InvoiceData(
      invoiceNo: '224',
      date: '12-Oct-26',
      dispatch: 'By HAND',
      consigneeName: 'A',
      consigneeAddress: 'B',
      gstin: 'G',
      items: regularBill224Items(),
      cgstPercent: 0,
      sgstPercent: 0,
      igstPercent: 18,
      cgstAmountOverride: 0,
      sgstAmountOverride: 0,
      igstAmountOverride: 4730.40,
      grandTotalOverride: 35710.80,
      amountInWords: 'THIRTY FIVE THOUSAND SEVEN HUNDRED ELEVEN ONLY',
      bankName: 'STATE BANK OF INDIA',
      accountNo: '1',
      ifscCode: 'SBIN0040552',
      bankAddress: 'SINGASANDRA',
    );
    expect(wrongStored.grandTotal, closeTo(35710.80, 0.001));
    expect(wrongStored.lineGrandTotal, closeTo(31010.40, 0.001));
    expect(formatUltraAmountInWords(wrongStored.lineGrandTotal),
        'THIRTY ONE THOUSAND TEN ONLY');
  });

  test('normal bill DC date is 0 when the DC number is 0 or empty', () {
    expect(salesBillDcDateCell(dcNo: '0', dcDate: '12-Oct-26'), '0');
    expect(salesBillDcDateCell(dcNo: '', dcDate: '12-Oct-26'), '0');
    expect(salesBillDcDateCell(dcNo: '338', dcDate: '12-Oct-26'), '12-Oct-26');
  });

  test('old invoice 208 prints the PO date and never 0', () {
    expect(formatSalesPoDate('2026-09-21'), '21-Sep-26');
    expect(formatSalesPoDate(DateTime.utc(2026, 9, 21)), '21-Sep-26');
    expect(formatSalesPoDate('09/21/2026'), '21-Sep-26');
    expect(formatSalesPoDate(0), '');
    expect(formatSalesPoDate('0'), '');
    expect(formatSalesPoDate(null), '');
    expect(salesBillPoDateCell(formatSalesPoDate(0)), '');
    expect(salesBillPoDateCell('21-Sep-26'), '21-Sep-26');
    expect(salesBillPoDateCell(''), isNot('0'));
  });

  test('consignee address drops doubled commas and a repeated pincode line', () {
    const raw =
        'PLOT NO. G104/1 39PART & 40 PART,, VILLAGE VALLAM A VADAGAL,, SRIPERUMBUDUR, - KANCHIPURAM,, CHENNAI, 602 105';
    final cleaned = cleanConsigneeAddress(raw);
    expect(cleaned.contains(',,'), isFalse);
    expect(cleaned.contains(' - '), isFalse);
    expect(cleaned, contains('CHENNAI'));
    expect(cleaned, contains('602 105'));
    expect(
      consigneeCityLineForPrint(
        address: cleaned,
        cityLine: 'CHENNAI - 602105',
      ),
      '',
    );
    expect(
      consigneeCityLineForPrint(
        address: 'Some other road',
        cityLine: 'CHENNAI - 602105',
      ),
      'CHENNAI - 602105',
    );
  });

  test('formatUltraAmountInWords examples', () {
    expect(formatUltraAmountInWords(31010.40), 'THIRTY ONE THOUSAND TEN ONLY');
    expect(formatUltraAmountInWords(15292.80),
        'FIFTEEN THOUSAND TWO HUNDRED AND NINETY THREE ONLY');
    expect(formatUltraAmountInWords(44320.80),
        'FORTY FOUR THOUSAND THREE HUNDRED AND TWENTY ONE ONLY');
  });

  test('sales bill words match the printed G.Total, including paise', () {
    expect(
      formatSalesBillAmountInWords(5380.80),
      'FIVE THOUSAND THREE HUNDRED AND EIGHTY RUPEES AND EIGHTY PAISE ONLY',
    );
    expect(formatUltraMoney(5380.80), '5,380.80');
    expect(
      formatSalesBillAmountInWords(44320.80),
      'FORTY FOUR THOUSAND THREE HUNDRED AND TWENTY RUPEES AND EIGHTY PAISE ONLY',
    );
    expect(formatUltraMoney(44320.80), '44,320.80');
    expect(
      formatSalesBillAmountInWords(44320),
      'FORTY FOUR THOUSAND THREE HUNDRED AND TWENTY RUPEES ONLY',
    );
    expect(formatUltraMoney(44320), '44,320.00');
    expect(formatSalesBillAmountInWords(44320), isNot(contains('PAISE')));
  });

  test('labour DC cells print blank for empty and zero, and keep real numbers',
      () {
    expect(labourPrintedDcNumber(''), '');
    expect(labourPrintedDcNumber('0'), '');
    expect(labourPrintedDcNumber(' 0 '), '');
    expect(
      labourPrintedSelDcDate(
        selDcNo: '',
        selDcDate: '25-Sep-26',
        invoiceDate: '28 September 2026',
      ),
      '',
    );
    expect(
      labourPrintedSelDcDate(
        selDcNo: '0',
        selDcDate: '25-Sep-26',
        invoiceDate: '28 September 2026',
      ),
      '',
    );
    expect(
      labourPrintedUewDcDate(dcNo: '', dcDate: '28/09/2026'),
      '',
    );
    expect(
      labourPrintedUewDcDate(dcNo: '0', dcDate: '28/09/2026'),
      '',
    );

    expect(labourPrintedDcNumber('927000483'), '927000483');
    expect(labourPrintedDcNumber('299'), '299');
    expect(
      labourPrintedSelDcDate(
        selDcNo: '927000483',
        selDcDate: '25-Sep-26',
        invoiceDate: '28 September 2026',
      ),
      '25-Sep-26',
    );
    expect(
      labourPrintedUewDcDate(dcNo: '299', dcDate: '28/09/2026'),
      '28/09/2026',
    );
    expect(
      labourPrintedSelDcDate(
        selDcNo: '927000483',
        selDcDate: '',
        invoiceDate: '28 September 2026',
      ),
      '28 September 2026',
    );
    expect(labourPrintedUewDcDate(dcNo: '299', dcDate: ''), '0');
  });

  test('empty labour shipping address falls back to consignee address lines',
      () {
    expect(
      labourShippingAddressLines(
        shippingAddress: '',
        consigneeAddress: billSampleAddress,
        consigneeCityLine: billSampleCity,
      ),
      [billSampleAddress, billSampleCity],
    );
    expect(
      labourShippingAddressLines(
        shippingAddress: '   ',
        consigneeAddress: billSampleAddress,
        consigneeCityLine: billSampleCity,
      ),
      [billSampleAddress, billSampleCity],
    );
    expect(
      labourShippingAddressLines(
        shippingAddress: 'SHIP ONLY',
        consigneeAddress: billSampleAddress,
        consigneeCityLine: billSampleCity,
      ),
      ['SHIP ONLY'],
    );
  });
}

const billSampleAddress = 'CONS ADDR LINE';
const billSampleCity = 'CITY - 560099';
