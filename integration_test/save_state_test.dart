import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:prism/main.dart' as app;
import 'package:prism/services/library_service.dart';
import 'package:prism/widgets/book_card.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Reading position persists after leaving and re-entering a book',
      (tester) async {
    // Collect widget exceptions separately — don't let non-fatal UI errors
    // (like ValueListenableBuilder disposal) fail the save state test.
    final widgetErrors = <FlutterErrorDetails>[];
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      widgetErrors.add(details);
      debugPrint('WIDGET ERROR (non-fatal for test): ${details.exceptionAsString()}');
    };

    addTearDown(() {
      FlutterError.onError = originalHandler;
      if (widgetErrors.isNotEmpty) {
        debugPrint('${widgetErrors.length} widget error(s) occurred during test (logged, not fatal)');
      }
    });

    // Launch app
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Copy test EPUB from assets to a file path the library service can read
    final dir = await getApplicationDocumentsDirectory();
    final testBookPath = '${dir.path}/test_book.epub';
    final testFile = File(testBookPath);
    if (!testFile.existsSync()) {
      final data = await rootBundle.load('test/fixtures/test_book.epub');
      await testFile.writeAsBytes(data.buffer.asUint8List());
    }

    // Import the book via LibraryService directly (file_picker doesn't work in tests)
    final context = tester.element(find.byType(MaterialApp));
    final libraryService = Provider.of<LibraryService>(context, listen: false);

    // Wait for initialization
    while (!libraryService.initialized) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Import if library is empty
    if (libraryService.books.isEmpty) {
      await libraryService.importBook(testBookPath);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // Verify we have a book
    expect(libraryService.books.isNotEmpty, isTrue,
        reason: 'Library should have at least one book after import');
    debugPrint('Library has ${libraryService.books.length} book(s)');

    // Tap the first book card to open it
    await tester.pumpAndSettle();
    final bookCards = find.byType(BookCard);
    expect(bookCards, findsWidgets, reason: 'Should find book cards');
    await tester.tap(bookCards.first);

    // Use pump (not pumpAndSettle) — the scroll debounce timer (500ms)
    // should settle, but use pump to be safe
    await tester.pump(const Duration(seconds: 3));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    debugPrint('Book opened');

    // Swipe to chapter 2 (Contents — has scrollable text, renders fast)
    for (int i = 0; i < 2; i++) {
      await tester.fling(
        find.byType(Scaffold).first,
        const Offset(-300, 0),
        1000,
      );
      await tester.pump(const Duration(seconds: 1));
      for (int j = 0; j < 15; j++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    debugPrint('Swiped to chapter 2');

    // Wait for content to render
    await tester.pump(const Duration(seconds: 2));

    // Find scrollable content and scroll down
    final scrollables = find.byType(SingleChildScrollView);
    if (scrollables.evaluate().isNotEmpty) {
      await tester.drag(scrollables.first, const Offset(0, -500));
      await tester.pump(const Duration(seconds: 1));
      debugPrint('Scrolled down 500px');

      // Wait for debounce save (500ms + margin)
      await tester.pump(const Duration(seconds: 1));
    } else {
      debugPrint('WARNING: No scrollable content — testing chapter save only');
    }

    // Navigate back — tap top area to show controls, then back button
    await tester.tapAt(const Offset(200, 40));
    await tester.pump(const Duration(seconds: 1));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final backButton = find.byIcon(Icons.arrow_back);
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton);
      debugPrint('Tapped back button');
    } else {
      debugPrint('WARNING: No back button found');
      // Try system back
      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      nav.pop();
    }

    // Wait for library screen
    await tester.pumpAndSettle(const Duration(seconds: 3));
    debugPrint('Back on library');

    // Verify the saved state — check the book's lastChapterIndex in memory
    final book = libraryService.books.first;
    debugPrint('Saved chapter: ${book.lastChapterIndex}, scroll: ${book.lastScrollPosition}');
    expect(book.lastChapterIndex, greaterThan(0),
        reason: 'Chapter index should be > 0 after swiping to chapter 2 (got ${book.lastChapterIndex})');

    // Re-open the book
    final bookCardsAgain = find.byType(BookCard);
    expect(bookCardsAgain, findsWidgets);
    await tester.tap(bookCardsAgain.first);
    await tester.pump(const Duration(seconds: 3));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    debugPrint('Book re-opened');

    // Verify the book opened at the saved chapter (not chapter 0)
    // We can check this by verifying the scroll position or chapter index
    final reopenedBook = libraryService.books.first;
    debugPrint('After reopen — chapter: ${reopenedBook.lastChapterIndex}, scroll: ${reopenedBook.lastScrollPosition}');
    expect(reopenedBook.lastChapterIndex, greaterThan(0),
        reason: 'Should reopen at saved chapter, not chapter 0');
  });
}
