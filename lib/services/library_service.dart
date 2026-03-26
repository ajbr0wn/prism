import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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

  /// Import an EPUB file into the library.
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

    // Parse epub to get metadata
    final parsed = await EpubService.parse(destPath);

    // Save cover image if available
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
    );

    _books.insert(0, book);
    await _saveBooks();
    notifyListeners();

    return book;
  }

  /// Remove a book from the library and delete its files.
  Future<void> removeBook(String bookId) async {
    final book = _books.firstWhere((b) => b.id == bookId);

    // Delete the epub file
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
    // Don't notifyListeners for progress updates to avoid rebuilds
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
