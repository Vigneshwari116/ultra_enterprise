import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_enterprise/widgets/transaction_line_math.dart';

void main() {
  test('catalogPurchaseRate reads purchase_rate not sales_rate', () {
    final product = {
      'id': 1,
      'product_name': 'FINAL TEST PRODUCT',
      'purchase_rate': 100,
      'sales_rate': 150,
    };
    expect(catalogPurchaseRate(product), 100);
    expect(catalogSalesRate(product), 150);
  });

  test('formatTransactionMatrixRate shows two-decimal purchase rate', () {
    expect(formatTransactionMatrixRate(100), '100.00');
    expect(formatTransactionMatrixRate(0, blankZero: true), '');
  });
}
