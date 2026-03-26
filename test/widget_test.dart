import 'package:flutter_test/flutter_test.dart';

import 'package:prism/main.dart';

void main() {
  testWidgets('App starts and shows library screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PrismApp());
    expect(find.text('Prism'), findsOneWidget);
  });
}
