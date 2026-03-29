import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism/main.dart';

void main() {
  testWidgets('App starts and shows library screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PrismApp());
    // Logo image replaces text — check for the Image widget instead
    expect(find.byType(Image), findsWidgets);
  });
}
