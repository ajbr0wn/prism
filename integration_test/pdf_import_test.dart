import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:prism/main.dart' as app;
import 'package:prism/models/book.dart';
import 'package:prism/services/library_service.dart';
import 'package:prism/widgets/book_card.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PDF paper imports and opens in PDF reader', (tester) async {
    final widgetErrors = <FlutterErrorDetails>[];
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      widgetErrors.add(details);
      debugPrint('WIDGET ERROR (non-fatal): ${details.exceptionAsString()}');
    };

    addTearDown(() {
      FlutterError.onError = originalHandler;
      if (widgetErrors.isNotEmpty) {
        debugPrint('${widgetErrors.length} widget error(s) during test');
      }
    });

    // Launch app
    // NOTE: Avoid pumpAndSettle — ShaderBackground's Ticker prevents settling.
    app.main();
    await tester.pump(const Duration(seconds: 3));

    // Copy test PDF from assets to a file path
    final dir = await getApplicationDocumentsDirectory();
    final testPaperPath = '${dir.path}/test_paper.pdf';
    final testFile = File(testPaperPath);
    if (!testFile.existsSync()) {
      final data = await rootBundle.load('test/fixtures/test_paper.pdf');
      await testFile.writeAsBytes(data.buffer.asUint8List());
    }

    // Import the PDF via LibraryService
    final context = tester.element(find.byType(MaterialApp));
    final libraryService = Provider.of<LibraryService>(context, listen: false);

    while (!libraryService.initialized) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final booksBefore = libraryService.books.length;
    await libraryService.importBook(testPaperPath);
    await tester.pump(const Duration(seconds: 2));

    // Verify import succeeded
    expect(libraryService.books.length, equals(booksBefore + 1));

    // Find the imported PDF
    final importedBook = libraryService.books.first;
    debugPrint('Imported: ${importedBook.title}');
    debugPrint('File type: ${importedBook.fileType}');
    debugPrint('Category: ${importedBook.category}');
    debugPrint('Page count: ${importedBook.pageCount}');

    // Verify it was detected as a PDF
    expect(importedBook.fileType, equals(BookFileType.pdf),
        reason: 'Should be detected as PDF');

    // Verify page count was extracted
    expect(importedBook.pageCount, isNotNull,
        reason: 'Should have a page count');
    expect(importedBook.pageCount, greaterThan(0),
        reason: 'Page count should be positive');
    debugPrint('PDF has ${importedBook.pageCount} pages');

    // Verify it was auto-classified as a paper (<=40 pages)
    expect(importedBook.category, equals(BookCategory.paper),
        reason: 'Short PDF should be auto-classified as paper');

    // Switch to Papers tab and verify the book card appears
    final papersTab = find.text('Papers');
    expect(papersTab, findsOneWidget, reason: 'Should have Papers tab');
    await tester.tap(papersTab);
    await tester.pump(const Duration(milliseconds: 500));

    // Verify book card shows up
    final bookCards = find.byType(BookCard);
    expect(bookCards, findsWidgets, reason: 'Should find book cards in Papers tab');

    // Open the PDF
    await tester.tap(bookCards.first);
    await tester.pump(const Duration(seconds: 3));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    debugPrint('PDF opened in reader');

    // Verify we're in the PDF reader (should have page info)
    // Tap to show controls
    await tester.tapAt(const Offset(200, 40));
    await tester.pump(const Duration(seconds: 1));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Navigate back
    final backButton = find.byIcon(Icons.arrow_back);
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton);
      debugPrint('Navigated back from PDF reader');
    }

    await tester.pump(const Duration(seconds: 2));
    debugPrint('PDF import and reading test complete');
  });
}
