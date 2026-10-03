import 'package:test/test.dart';
import 'package:ultra_api_server/http.dart';

void main() {
  test('jsonError encodes message', () async {
    final res = jsonError('bad request', status: 422);
    expect(res.statusCode, 422);
    expect(await res.readAsString(), '{"error":"bad request"}');
  });
}
