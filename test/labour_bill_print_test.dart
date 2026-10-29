import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_enterprise/widgets/invoice.dart';
import 'package:ultra_enterprise/widgets/ultra_print_helpers.dart';

import 'support/bill_sample_data.dart';
import 'support/pdf_shown_text.dart';

void main() {
  const oneCopy = ['ORIGINAL FOR RECIPIENT'];

  Future<String> printed(InvoiceData data) async {
    final bytes = await buildUltraInvoicePdf(data, copyLabels: oneCopy);
    return pdfShownPlainText(bytes);
  }

  test('labour DC rows print blank for an empty number and its date', () async {
    final text = await printed(labourBillSample(
      selDcNo: '',
      selDcDate: '25-Sep-26',
      dcNo: '',
      dcDate: '28/09/2026',
    ));
    expect(text, contains('SEL DC NO : UEW DC.NO : DESPATCH :'));
    expect(text, isNot(contains('25-Sep-26')));
    expect(text, isNot(contains('28/09/2026')));
  });

  test('labour DC rows print blank when the number is 0', () async {
    final text = await printed(labourBillSample(
      selDcNo: '0',
      selDcDate: '25-Sep-26',
      dcNo: '0',
      dcDate: '28/09/2026',
    ));
    expect(text, contains('SEL DC NO : UEW DC.NO : DESPATCH :'));
    expect(text, isNot(contains('25-Sep-26')));
    expect(text, isNot(contains('28/09/2026')));
  });

  test('SEL 927000483 and UEW 299 print in their own cells', () async {
    final text = await printed(labourBillSample(
      selDcNo: '927000483',
      selDcDate: '25-Sep-26',
      dcNo: '299',
      dcDate: '28/09/2026',
    ));
    expect(
      text,
      contains('SEL DC NO : 927000483 25-Sep-26 UEW DC.NO : 299 28/09/2026'),
    );
    expect(text, isNot(contains('SEL DC NO : 299')));
    expect(text, isNot(contains('UEW DC.NO : 927000483')));
  });

  test(
      'empty shipping address prints consignee address lines under the shipping name',
      () async {
    const shipName = 'SHIP TO UNIT 4';
    const consigneeAddress = 'CONS ADDR LINE THAT IS UNIQUE';
    const city = 'CITYPIN - 560111';
    final text = await printed(labourBillSample(
      shippingName: shipName,
      shippingAddress: '',
      consigneeAddress: consigneeAddress,
      consigneeCityLine: city,
    ));
    const header = 'SHIPPING NAME & ADDRESS OF CONSIGNE';
    final shipAt = text.indexOf(header);
    expect(shipAt, greaterThanOrEqualTo(0));
    final after = text.substring(shipAt, text.indexOf('SL.NO', shipAt));
    expect(
      after,
      contains('$header $shipName $consigneeAddress $city'),
    );
  });

  test(
      'a saved shipping address is printed and does not pick up the consignee city',
      () async {
    const shipName = 'SHIP TO UNIT 4';
    const shippingAddress = 'SHIP ADDR ONLY';
    const city = 'CITYPIN - 560111';
    final text = await printed(labourBillSample(
      shippingName: shipName,
      shippingAddress: shippingAddress,
      consigneeCityLine: city,
    ));
    const header = 'SHIPPING NAME & ADDRESS OF CONSIGNE';
    final shipAt = text.indexOf(header);
    final after = text.substring(shipAt, text.indexOf('SL.NO', shipAt));
    expect(after, contains('$header $shipName $shippingAddress'));
    expect(after, isNot(contains(city)));
  });

  InvoiceItem priced(double price) => InvoiceItem(
        description: 'JOB WORK',
        hsnCode: '',
        qty: 1,
        price: price,
      );

  test('labour rupees in words match printed G.Total with and without paise',
      () async {
    final withPaise = await printed(labourBillSample(
      invoiceNo: '206',
      items: [priced(5380.60)],
      cgstAmountOverride: 0,
      sgstAmountOverride: 0,
      igstAmountOverride: 0,
      roundOff: 0.20,
      grandTotalOverride: 99999,
      amountInWords: 'FIVE THOUSAND THREE HUNDRED AND EIGHTY ONE ONLY',
    ));
    expect(withPaise, contains('G.Total : 5,380.80'));
    expect(withPaise, contains('Round Off : 0.20'));
    expect(
      withPaise,
      contains(
        'FIVE THOUSAND THREE HUNDRED AND EIGHTY RUPEES AND EIGHTY PAISE ONLY',
      ),
    );
    expect(
      withPaise,
      isNot(contains('FIVE THOUSAND THREE HUNDRED AND EIGHTY ONE')),
    );

    final alsoPaise = await printed(labourBillSample(
      items: [priced(44320.80)],
      cgstAmountOverride: 0,
      sgstAmountOverride: 0,
      igstAmountOverride: 0,
      grandTotalOverride: 1,
      amountInWords: 'FORTY FOUR THOUSAND THREE HUNDRED AND TWENTY ONE ONLY',
    ));
    expect(alsoPaise, contains('G.Total : 44,320.80'));
    expect(
      alsoPaise,
      contains(
        'FORTY FOUR THOUSAND THREE HUNDRED AND TWENTY RUPEES AND EIGHTY PAISE ONLY',
      ),
    );
    expect(
      alsoPaise,
      isNot(contains('FORTY FOUR THOUSAND THREE HUNDRED AND TWENTY ONE')),
    );

    final whole = await printed(labourBillSample(
      items: [priced(44320)],
      cgstAmountOverride: 0,
      sgstAmountOverride: 0,
      igstAmountOverride: 0,
      grandTotalOverride: 1,
      amountInWords: 'SHOULD NOT PRINT',
    ));
    expect(whole, contains('G.Total : 44,320.00'));
    expect(
      whole,
      contains('FORTY FOUR THOUSAND THREE HUNDRED AND TWENTY RUPEES ONLY'),
    );
    expect(whole, isNot(contains('PAISE')));
    expect(whole, isNot(contains('SHOULD NOT PRINT')));
  });

  test('normal bill words follow G.Total when they used to be rounded',
      () async {
    final text = await printed(normalBillSample(
      items: [priced(5380.60)],
      cgstAmountOverride: 0,
      sgstAmountOverride: 0,
      igstAmountOverride: 0,
      roundOff: 0.20,
      grandTotalOverride: 99999,
      amountInWords: 'FIVE THOUSAND THREE HUNDRED AND EIGHTY ONE ONLY',
    ));
    expect(text, contains('G.Total : 5,380.80'));
    expect(text, contains('Round Off : 0.20'));
    expect(
      text,
      contains(
        'FIVE THOUSAND THREE HUNDRED AND EIGHTY RUPEES AND EIGHTY PAISE ONLY',
      ),
    );
    expect(
      text,
      isNot(contains('FIVE THOUSAND THREE HUNDRED AND EIGHTY ONE')),
    );
  });

  test('normal bill still prints an empty DC number as 0', () async {
    final text = await printed(normalBillSample(dcNo: '', dcDate: '12-Oct-26'));
    expect(text, contains('D.C.NO : 0 0'));
  });

  test('proforma keeps whole-rupee words for its line G.Total', () async {
    final text = await printed(proformaSample());
    expect(text, contains('G.Total : 31,010.40'));
    expect(text, contains('THIRTY ONE THOUSAND TEN ONLY'));
    expect(text, isNot(contains('RUPEES AND FORTY PAISE')));
    expect(text, isNot(contains('35,710.80')));
  });

  test('printed sales-bill words use the same figure as formatUltraMoney', () {
    expect(
      formatSalesBillAmountInWords(5380.80),
      'FIVE THOUSAND THREE HUNDRED AND EIGHTY RUPEES AND EIGHTY PAISE ONLY',
    );
    expect(formatUltraMoney(5380.80), '5,380.80');
  });
}
