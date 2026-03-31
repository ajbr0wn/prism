enum BookFileType { epub, pdf }
enum BookCategory { book, paper }

class Book {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final DateTime addedAt;
  final String? coverPath;
  final int lastChapterIndex;
  final double lastScrollPosition;
  final String? themeId;
  final BookFileType fileType;
  final BookCategory category;
  final int? pageCount;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.addedAt,
    this.coverPath,
    this.lastChapterIndex = 0,
    this.lastScrollPosition = 0.0,
    this.themeId,
    this.fileType = BookFileType.epub,
    this.category = BookCategory.book,
    this.pageCount,
  });

  bool get isPdf => fileType == BookFileType.pdf;
  bool get isPaper => category == BookCategory.paper;

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    DateTime? addedAt,
    String? coverPath,
    int? lastChapterIndex,
    double? lastScrollPosition,
    String? themeId,
    BookFileType? fileType,
    BookCategory? category,
    int? pageCount,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      addedAt: addedAt ?? this.addedAt,
      coverPath: coverPath ?? this.coverPath,
      lastChapterIndex: lastChapterIndex ?? this.lastChapterIndex,
      lastScrollPosition: lastScrollPosition ?? this.lastScrollPosition,
      themeId: themeId ?? this.themeId,
      fileType: fileType ?? this.fileType,
      category: category ?? this.category,
      pageCount: pageCount ?? this.pageCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'filePath': filePath,
        'addedAt': addedAt.toIso8601String(),
        'coverPath': coverPath,
        'lastChapterIndex': lastChapterIndex,
        'lastScrollPosition': lastScrollPosition,
        'themeId': themeId,
        'fileType': fileType.name,
        'category': category.name,
        'pageCount': pageCount,
      };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as String,
        title: json['title'] as String,
        author: json['author'] as String,
        filePath: json['filePath'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
        coverPath: json['coverPath'] as String?,
        lastChapterIndex: json['lastChapterIndex'] as int? ?? 0,
        lastScrollPosition: (json['lastScrollPosition'] as num?)?.toDouble() ?? 0.0,
        themeId: json['themeId'] as String?,
        fileType: BookFileType.values.firstWhere(
          (e) => e.name == json['fileType'],
          orElse: () => BookFileType.epub,
        ),
        category: BookCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => BookCategory.book,
        ),
        pageCount: json['pageCount'] as int?,
      );
}

class ParsedEpub {
  final String title;
  final String author;
  final List<EpubChapter> chapters;
  final List<int>? coverImageBytes;

  const ParsedEpub({
    required this.title,
    required this.author,
    required this.chapters,
    this.coverImageBytes,
  });
}

class EpubChapter {
  final String title;
  final String content; // XHTML content
  final String href; // File path within the epub (e.g. "chapter1.xhtml")

  const EpubChapter({
    required this.title,
    required this.content,
    required this.href,
  });
}
