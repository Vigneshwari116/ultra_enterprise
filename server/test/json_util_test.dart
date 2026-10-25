import 'dart:convert';

import 'package:test/test.dart';
import 'package:ultra_api_server/json_util.dart';

void main() {
  test('flattenEnvelopeRow merges JSON string data', () {
    final row = {
      'id': 7,
      'status': 'POSTED',
      'data': jsonEncode({'voucher_no': 12, 'grand_total': 118}),
    };
    final flat = flattenEnvelopeRow(row);
    expect(flat['id'], 7);
    expect(flat['voucher_no'], 12);
    expect(flat['grand_total'], 118);
    expect(flat.containsKey('data'), isFalse);
  });

  test('flattenEnvelopeRow preserves top-level keys over inner', () {
    final flat = flattenEnvelopeRow({
      'id': 1,
      'status': 'LIVE',
      'data': {'status': 'POSTED', 'voucher_no': 5},
    });
    expect(flat['status'], 'LIVE');
    expect(flat['voucher_no'], 5);
  });
}
