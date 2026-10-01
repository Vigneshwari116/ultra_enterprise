import 'package:flutter_test/flutter_test.dart';

import 'package:ultra_enterprise/main.dart';

void main() {
  testWidgets('UltraApp builds login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const UltraApp());
    await tester.pump();

    expect(find.text('System Sign In'), findsOneWidget);
  });
}
