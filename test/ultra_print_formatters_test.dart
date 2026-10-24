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

  test('formatUltraAmountInWords examples', () {
    expect(formatUltraAmountInWords(31010.40),
        'THIRTY ONE THOUSAND TEN ONLY');
    expect(formatUltraAmountInWords(15292.80),
        'FIFTEEN THOUSAND TWO HUNDRED AND NINETY THREE ONLY');
    expect(formatUltraAmountInWords(44320.80),
        'FORTY FOUR THOUSAND THREE HUNDRED AND TWENTY ONE ONLY');
  });
}
