import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism/models/book.dart';

void main() {
  group('Book model file type and category support', () {
    test('defaults to epub file type and book category', () {
      final book = Book(
        id: 'test',
        title: 'Test',
        author: 'Author',
        filePath: '/path/book.epub',
        addedAt: DateTime(2026, 3, 31),
      );

      expect(book.fileType, equals(BookFileType.epub));
      expect(book.category, equals(BookCategory.book));
      expect(book.isPdf, isFalse);
      expect(book.isPaper, isFalse);
      expect(book.pageCount, isNull);
    });

    test('PDF book with paper category round-trips through JSON', () {
      final book = Book(
        id: 'paper-1',
        title: 'Test Paper',
        author: 'Researcher',
        filePath: '/path/paper.pdf',
        addedAt: DateTime(2026, 3, 31),
        fileType: BookFileType.pdf,
        category: BookCategory.paper,
        pageCount: 13,
      );

      final json = book.toJson();
      final restored = Book.fromJson(json);

      expect(restored.fileType, equals(BookFileType.pdf));
      expect(restored.category, equals(BookCategory.paper));
      expect(restored.isPdf, isTrue);
      expect(restored.isPaper, isTrue);
      expect(restored.pageCount, equals(13));
    });

    test('backwards compatibility: missing fileType/category defaults correctly', () {
      final json = {
        'id': 'old-book',
        'title': 'Old Book',
        'author': 'Author',
        'filePath': '/path/old.epub',
        'addedAt': '2026-03-27T00:00:00.000',
        'lastChapterIndex': 5,
        'lastScrollPosition': 100.0,
      };

      final book = Book.fromJson(json);
      expect(book.fileType, equals(BookFileType.epub));
      expect(book.category, equals(BookCategory.book));
      expect(book.isPdf, isFalse);
      expect(book.isPaper, isFalse);
      expect(book.pageCount, isNull);
    });

    test('copyWith updates category correctly', () {
      final book = Book(
        id: 'test',
        title: 'Test',
        author: 'Author',
        filePath: '/path/doc.pdf',
        addedAt: DateTime(2026, 3, 31),
        fileType: BookFileType.pdf,
        category: BookCategory.book,
        pageCount: 200,
      );

      final reclassified = book.copyWith(category: BookCategory.paper);
      expect(reclassified.isPaper, isTrue);
      expect(reclassified.isPdf, isTrue);
      expect(reclassified.pageCount, equals(200));
      // Original unchanged
      expect(book.isPaper, isFalse);
    });

    test('mixed library JSON preserves file types and categories', () {
      final books = [
        Book(
          id: 'epub-1',
          title: 'Novel',
          author: 'Author',
          filePath: '/path/novel.epub',
          addedAt: DateTime(2026, 3, 31),
          fileType: BookFileType.epub,
          category: BookCategory.book,
        ),
        Book(
          id: 'pdf-1',
          title: 'Textbook',
          author: 'Prof',
          filePath: '/path/textbook.pdf',
          addedAt: DateTime(2026, 3, 31),
          fileType: BookFileType.pdf,
          category: BookCategory.book,
          pageCount: 500,
        ),
        Book(
          id: 'paper-1',
          title: 'Research Paper',
          author: 'Researcher',
          filePath: '/path/paper.pdf',
          addedAt: DateTime(2026, 3, 31),
          fileType: BookFileType.pdf,
          category: BookCategory.paper,
          pageCount: 12,
        ),
      ];

      final jsonString = jsonEncode(books.map((b) => b.toJson()).toList());
      final decoded = (jsonDecode(jsonString) as List)
          .map((j) => Book.fromJson(j as Map<String, dynamic>))
          .toList();

      expect(decoded[0].fileType, equals(BookFileType.epub));
      expect(decoded[0].category, equals(BookCategory.book));

      expect(decoded[1].fileType, equals(BookFileType.pdf));
      expect(decoded[1].category, equals(BookCategory.book));
      expect(decoded[1].pageCount, equals(500));

      expect(decoded[2].fileType, equals(BookFileType.pdf));
      expect(decoded[2].category, equals(BookCategory.paper));
      expect(decoded[2].pageCount, equals(12));
    });
  });
}
