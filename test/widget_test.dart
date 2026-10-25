import 'package:flutter_test/flutter_test.dart';

import 'package:ultra_enterprise/main.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const UltraApp());
    expect(find.text('System Sign In'), findsOneWidget);
  });
}
