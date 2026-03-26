import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/highlight.dart';

class HighlightService extends ChangeNotifier {
  final Map<String, List<Highlight>> _highlights = {};
  String? _storagePath;
  bool _initialized = false;

  bool get initialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _storagePath = '${dir.path}/prism/highlights';
    await Directory(_storagePath!).create(recursive: true);
    _initialized = true;
  }

  /// Get all highlights for a book.
  List<Highlight> getHighlightsForBook(String bookId) {
    return _highlights[bookId] ?? [];
  }

  /// Get highlights for a specific chapter.
  List<Highlight> getHighlightsForChapter(String bookId, int chapterIndex) {
    return getHighlightsForBook(bookId)
        .where((h) => h.chapterIndex == chapterIndex)
        .toList();
  }

  /// Load highlights for a book (call when opening a book).
  Future<void> loadHighlightsForBook(String bookId) async {
    if (_storagePath == null) return;
    final file = File('$_storagePath/$bookId.json');
    if (!await file.exists()) {
      _highlights[bookId] = [];
      return;
    }

    try {
      final json = jsonDecode(await file.readAsString()) as List<dynamic>;
      _highlights[bookId] = json
          .map((item) => Highlight.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading highlights for $bookId: $e');
      _highlights[bookId] = [];
    }
    notifyListeners();
  }

  /// Add a highlight.
  Future<void> addHighlight(Highlight highlight) async {
    final list = _highlights.putIfAbsent(highlight.bookId, () => []);
    list.add(highlight);
    list.sort((a, b) {
      final chapterCompare = a.chapterIndex.compareTo(b.chapterIndex);
      if (chapterCompare != 0) return chapterCompare;
      final paraCompare = a.paragraphIndex.compareTo(b.paragraphIndex);
      if (paraCompare != 0) return paraCompare;
      return a.startOffset.compareTo(b.startOffset);
    });
    await _save(highlight.bookId);
    notifyListeners();
  }

  /// Remove a highlight.
  Future<void> removeHighlight(String bookId, String highlightId) async {
    _highlights[bookId]?.removeWhere((h) => h.id == highlightId);
    await _save(bookId);
    notifyListeners();
  }

  /// Change a highlight's color.
  Future<void> changeHighlightColor(
      String bookId, String highlightId, int colorIndex) async {
    final list = _highlights[bookId];
    if (list == null) return;

    final index = list.indexWhere((h) => h.id == highlightId);
    if (index < 0) return;

    final old = list[index];
    list[index] = Highlight(
      id: old.id,
      bookId: old.bookId,
      chapterIndex: old.chapterIndex,
      paragraphIndex: old.paragraphIndex,
      startOffset: old.startOffset,
      endOffset: old.endOffset,
      text: old.text,
      colorIndex: colorIndex,
      createdAt: old.createdAt,
    );
    await _save(bookId);
    notifyListeners();
  }

  Future<void> _save(String bookId) async {
    if (_storagePath == null) return;
    final file = File('$_storagePath/$bookId.json');
    final list = _highlights[bookId] ?? [];
    await file.writeAsString(jsonEncode(list.map((h) => h.toJson()).toList()));
  }
}
