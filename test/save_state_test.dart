import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism/models/book.dart';

void main() {
  group('Book save state serialization', () {
    test('round-trips lastChapterIndex and lastScrollPosition through JSON', () {
      final book = Book(
        id: 'test-book-1',
        title: 'Test Book',
        author: 'Test Author',
        filePath: '/test/path.epub',
        addedAt: DateTime(2026, 3, 27),
        lastChapterIndex: 5,
        lastScrollPosition: 1234.56,
      );

      final json = book.toJson();
      final restored = Book.fromJson(json);

      expect(restored.lastChapterIndex, equals(5));
      expect(restored.lastScrollPosition, closeTo(1234.56, 0.01));
    });

    test('defaults to chapter 0 and scroll 0 when fields missing', () {
      final json = {
        'id': 'test',
        'title': 'Test',
        'author': 'Author',
        'filePath': '/path',
        'addedAt': '2026-03-27T00:00:00.000',
      };

      final book = Book.fromJson(json);
      expect(book.lastChapterIndex, equals(0));
      expect(book.lastScrollPosition, equals(0.0));
    });

    test('preserves scroll position through JSON string encoding', () {
      final book = Book(
        id: 'test',
        title: 'Test',
        author: 'Author',
        filePath: '/path',
        addedAt: DateTime(2026, 3, 27),
        lastChapterIndex: 12,
        lastScrollPosition: 9876.54,
      );

      // Simulate full persistence cycle: object -> JSON -> string -> JSON -> object
      final jsonString = jsonEncode(book.toJson());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final restored = Book.fromJson(decoded);

      expect(restored.lastChapterIndex, equals(12));
      expect(restored.lastScrollPosition, closeTo(9876.54, 0.01));
    });

    test('copyWith updates save state fields', () {
      final book = Book(
        id: 'test',
        title: 'Test',
        author: 'Author',
        filePath: '/path',
        addedAt: DateTime(2026, 3, 27),
        lastChapterIndex: 0,
        lastScrollPosition: 0.0,
      );

      final updated = book.copyWith(
        lastChapterIndex: 7,
        lastScrollPosition: 3000.0,
      );

      expect(updated.lastChapterIndex, equals(7));
      expect(updated.lastScrollPosition, equals(3000.0));
      // Original unchanged
      expect(book.lastChapterIndex, equals(0));
      expect(book.lastScrollPosition, equals(0.0));
    });

    test('handles zero scroll position correctly', () {
      final book = Book(
        id: 'test',
        title: 'Test',
        author: 'Author',
        filePath: '/path',
        addedAt: DateTime(2026, 3, 27),
        lastChapterIndex: 3,
        lastScrollPosition: 0.0,
      );

      final json = book.toJson();
      final restored = Book.fromJson(json);

      expect(restored.lastChapterIndex, equals(3));
      expect(restored.lastScrollPosition, equals(0.0));
    });

    test('library JSON preserves multiple books with different states', () {
      final books = [
        Book(
          id: 'book-1',
          title: 'Book One',
          author: 'Author',
          filePath: '/path/1.epub',
          addedAt: DateTime(2026, 3, 27),
          lastChapterIndex: 0,
          lastScrollPosition: 0.0,
        ),
        Book(
          id: 'book-2',
          title: 'Book Two',
          author: 'Author',
          filePath: '/path/2.epub',
          addedAt: DateTime(2026, 3, 27),
          lastChapterIndex: 15,
          lastScrollPosition: 5555.55,
        ),
      ];

      // Simulate library.json persistence
      final jsonString = jsonEncode(books.map((b) => b.toJson()).toList());
      final decoded = (jsonDecode(jsonString) as List)
          .map((j) => Book.fromJson(j as Map<String, dynamic>))
          .toList();

      expect(decoded[0].lastChapterIndex, equals(0));
      expect(decoded[0].lastScrollPosition, equals(0.0));
      expect(decoded[1].lastChapterIndex, equals(15));
      expect(decoded[1].lastScrollPosition, closeTo(5555.55, 0.01));
    });
  });
}
