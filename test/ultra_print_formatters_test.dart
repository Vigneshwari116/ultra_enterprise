import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_enterprise/widgets/ultra_print_helpers.dart';

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

  test('formatUltraAmountInWords examples', () {
    expect(formatUltraAmountInWords(31010.40),
        'THIRTY ONE THOUSAND TEN ONLY');
    expect(formatUltraAmountInWords(15292.80),
        'FIFTEEN THOUSAND TWO HUNDRED AND NINETY THREE ONLY');
    expect(formatUltraAmountInWords(44320.80),
        'FORTY FOUR THOUSAND THREE HUNDRED AND TWENTY ONE ONLY');
  });
}
