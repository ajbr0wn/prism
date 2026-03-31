import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/book.dart';
import 'epub_service.dart';

class LibraryService extends ChangeNotifier {
  List<Book> _books = [];
  String? _storagePath;
  bool _initialized = false;

  List<Book> get books => List.unmodifiable(_books);
  bool get initialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    _storagePath = '${dir.path}/prism';
    await Directory('$_storagePath/books').create(recursive: true);
    await Directory('$_storagePath/covers').create(recursive: true);
    await _loadBooks();
    _initialized = true;
    notifyListeners();
  }

  /// Import a book file (EPUB or PDF) into the library.
  /// Returns the imported Book, or throws on failure.
  Future<Book> importBook(String sourcePath) async {
    if (_storagePath == null) throw StateError('Library not initialized');

    // Generate a unique filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sourceFile = File(sourcePath);
    final ext = sourcePath.split('.').last.toLowerCase();
    final destFileName = '${timestamp}_book.$ext';
    final destPath = '$_storagePath/books/$destFileName';

    // Copy file to app storage
    await sourceFile.copy(destPath);

    if (ext == 'pdf') {
      return _importPdf(destPath, timestamp);
    } else {
      return _importEpub(destPath, timestamp);
    }
  }

  Future<Book> _importEpub(String destPath, int timestamp) async {
    final parsed = await EpubService.parse(destPath);

    String? coverPath;
    if (parsed.coverImageBytes != null) {
      coverPath = '$_storagePath/covers/${timestamp}_cover.jpg';
      await File(coverPath).writeAsBytes(parsed.coverImageBytes!);
    }

    final book = Book(
      id: timestamp.toString(),
      title: parsed.title,
      author: parsed.author,
      filePath: destPath,
      addedAt: DateTime.now(),
      coverPath: coverPath,
      fileType: BookFileType.epub,
    );

    _books.insert(0, book);
    await _saveBooks();
    notifyListeners();
    return book;
  }

  Future<Book> _importPdf(String destPath, int timestamp) async {
    final doc = await PdfDocument.openFile(destPath);

    // Extract metadata
    var title = 'Unknown Title';
    var author = 'Unknown Author';
    final pageCount = doc.pages.length;

    // Try to get metadata from PDF info dictionary
    try {
      final info = doc.permissions;
      // pdfrx exposes limited metadata — use filename as fallback title
      final fileName = destPath.split('/').last;
      final baseName = fileName.substring(
        fileName.indexOf('_') + 1,
        fileName.lastIndexOf('.'),
      );
      // Clean up the title from filename
      title = baseName
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .join(' ');
      if (title == 'Book') title = 'Untitled PDF';
    } catch (_) {
      // Use defaults
    }

    // Render first page as cover image
    String? coverPath;
    try {
      if (doc.pages.isNotEmpty) {
        final page = doc.pages[0];
        final fullWidth = 400.0;
        final fullHeight = fullWidth * (page.height / page.width);
        final pdfImage = await page.render(
          fullWidth: fullWidth,
          fullHeight: fullHeight,
        );
        if (pdfImage != null) {
          final uiImage = await pdfImage.createImage();
          final byteData = await uiImage.toByteData(
            format: ui.ImageByteFormat.png,
          );
          uiImage.dispose();
          if (byteData != null) {
            coverPath = '$_storagePath/covers/${timestamp}_cover.png';
            await File(coverPath).writeAsBytes(
              byteData.buffer.asUint8List(),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Could not render PDF cover: $e');
    }

    doc.dispose();

    // Auto-detect if this is likely an academic paper:
    // short page count and filename patterns
    final isPaper = pageCount <= 40 ||
        destPath.toLowerCase().contains('arxiv') ||
        destPath.toLowerCase().contains('paper');

    final book = Book(
      id: timestamp.toString(),
      title: title,
      author: author,
      filePath: destPath,
      addedAt: DateTime.now(),
      coverPath: coverPath,
      fileType: BookFileType.pdf,
      category: isPaper ? BookCategory.paper : BookCategory.book,
      pageCount: pageCount,
    );

    _books.insert(0, book);
    await _saveBooks();
    notifyListeners();
    return book;
  }

  /// Update the category of a book (book vs paper).
  Future<void> setCategory(String bookId, BookCategory category) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index < 0) return;

    _books[index] = _books[index].copyWith(category: category);
    await _saveBooks();
    notifyListeners();
  }

  /// Remove a book from the library and delete its files.
  Future<void> removeBook(String bookId) async {
    final book = _books.firstWhere((b) => b.id == bookId);

    // Delete the book file
    final bookFile = File(book.filePath);
    if (await bookFile.exists()) await bookFile.delete();

    // Delete cover if exists
    if (book.coverPath != null) {
      final coverFile = File(book.coverPath!);
      if (await coverFile.exists()) await coverFile.delete();
    }

    _books.removeWhere((b) => b.id == bookId);
    await _saveBooks();
    notifyListeners();
  }

  /// Update reading progress for a book.
  Future<void> updateProgress(
    String bookId, {
    int? chapterIndex,
    double? scrollPosition,
  }) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index < 0) return;

    _books[index] = _books[index].copyWith(
      lastChapterIndex: chapterIndex,
      lastScrollPosition: scrollPosition,
    );
    await _saveBooks();
    notifyListeners();
  }

  /// Set the theme for a specific book.
  Future<void> setBookTheme(String bookId, String? themeId) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index < 0) return;

    _books[index] = _books[index].copyWith(themeId: themeId);
    await _saveBooks();
    notifyListeners();
  }

  // ── Persistence ──

  Future<void> _loadBooks() async {
    final file = File('$_storagePath/library.json');
    if (!await file.exists()) return;

    try {
      final json = jsonDecode(await file.readAsString()) as List<dynamic>;
      _books = json
          .map((item) => Book.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading library: $e');
      _books = [];
    }
  }

  Future<void> _saveBooks() async {
    final file = File('$_storagePath/library.json');
    final json = _books.map((b) => b.toJson()).toList();
    await file.writeAsString(jsonEncode(json));
  }
}
