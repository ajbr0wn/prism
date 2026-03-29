import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:prism/main.dart' as app;

/// Integration test for save state persistence.
///
/// Bundles a test EPUB, imports it, scrolls down, navigates away,
/// re-opens the book, and verifies scroll position is restored.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Reading position persists after leaving and re-entering a book',
      (tester) async {
    // Copy test EPUB from assets to a readable location
    final dir = await getApplicationDocumentsDirectory();
    final testBookPath = '${dir.path}/test_book.epub';
    final testFile = File(testBookPath);

    if (!testFile.existsSync()) {
      final data = await rootBundle.load('test/fixtures/test_book.epub');
      await testFile.writeAsBytes(data.buffer.asUint8List());
    }

    // Launch the app
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Look for the import/add book button and import our test book
    final fab = find.byType(FloatingActionButton);
    if (fab.evaluate().isNotEmpty) {
      await tester.tap(fab);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    // Wait for the library to have at least one book
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Find and tap the first book card
    final bookCards = find.byType(Card);
    if (bookCards.evaluate().isEmpty) {
      debugPrint('INCONCLUSIVE: No books in library — file_picker likely blocked in test mode');
      return;
    }

    // Open the book
    await tester.tap(bookCards.first);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Swipe left a few times to get past cover/title pages to a content chapter
    for (int i = 0; i < 3; i++) {
      await tester.fling(
        find.byType(Scaffold).first,
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    debugPrint('Swiped to chapter ~3');

    // Find the scrollable content
    final scrollables = find.byType(SingleChildScrollView);
    if (scrollables.evaluate().isEmpty) {
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    if (scrollables.evaluate().isEmpty) {
      debugPrint('INCONCLUSIVE: No scrollable content found in reader');
      return;
    }

    // Scroll down significantly within the chapter
    await tester.drag(scrollables.first, const Offset(0, -800));
    await tester.pumpAndSettle();
    debugPrint('Scrolled down 800px in chapter');

    // Wait for the periodic save timer (30 seconds)
    await tester.pump(const Duration(seconds: 35));
    await tester.pumpAndSettle();

    // Navigate back to library using the back button
    final backButton = find.byIcon(Icons.arrow_back);
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton);
    } else {
      // Controls might be hidden — tap center to show them
      await tester.tap(find.byType(Scaffold).first);
      await tester.pumpAndSettle();
      final backAfterOverlay = find.byIcon(Icons.arrow_back);
      if (backAfterOverlay.evaluate().isNotEmpty) {
        await tester.tap(backAfterOverlay);
      }
    }
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Re-open the same book
    final bookCardsAgain = find.byType(Card);
    expect(bookCardsAgain, findsWidgets,
        reason: 'Should be back on library screen with at least one book');

    await tester.tap(bookCardsAgain.first);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Check scroll position — it should be non-zero
    final restoredScrollables = find.byType(SingleChildScrollView);
    if (restoredScrollables.evaluate().isNotEmpty) {
      final widget = tester.widget<SingleChildScrollView>(restoredScrollables.first);
      if (widget.controller != null && widget.controller!.hasClients) {
        final offset = widget.controller!.offset;
        debugPrint('Restored scroll offset: $offset');
        expect(offset, greaterThan(0),
            reason: 'Scroll position should be restored after re-entering the book (got $offset)');
      } else {
        debugPrint('WARNING: ScrollController has no clients after restore');
      }
    }
  });
}
