import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism/main.dart';
import 'package:prism/services/library_service.dart';

void main() {
  testWidgets('App starts and shows library screen', (WidgetTester tester) async {
    await tester.pumpWidget(PrismApp(
      libraryService: LibraryService(),
      syncService: null,
    ));
    // Logo image replaces text — check for the Image widget instead
    expect(find.byType(Image), findsWidgets);
  });
}
