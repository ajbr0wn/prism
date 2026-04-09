import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/library_service.dart';
import '../services/sync_service.dart';
import '../widgets/book_card.dart';
import 'pdf_reader_screen.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (kIsWeb) _loadWebTestBook();
  }

  /// On web, auto-load a bundled test epub so we can test rendering.
  Future<void> _loadWebTestBook() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final library = context.read<LibraryService>();
    if (library.books.isNotEmpty) return; // already loaded
    try {
      final data = await DefaultAssetBundle.of(context)
          .load('assets/test_book.epub');
      final bytes = data.buffer.asUint8List();
      await library.importBook('test_book.epub', bytes: bytes);
    } catch (e) {
      debugPrint('Web test book load failed: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFbbb7d0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Image.asset(
          'assets/images/prism_logo.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        actions: [
          _buildSyncIndicator(context),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4a4660),
          labelColor: const Color(0xFF2a2640),
          unselectedLabelColor: const Color(0xFF7a7690),
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'Books'),
            Tab(text: 'Papers'),
          ],
        ),
      ),
      body: Consumer<LibraryService>(
        builder: (context, library, child) {
          if (!library.initialized && !kIsWeb) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white24),
            );
          }

          final allBooks = library.books
              .where((b) => !b.isPaper)
              .toList();
          final allPapers = library.books
              .where((b) => b.isPaper)
              .toList();
          final recentBooks = library.recentBooks;

          return TabBarView(
            controller: _tabController,
            children: [
              // Books tab
              allBooks.isEmpty
                  ? _EmptyLibrary(
                      onImport: () => _importBook(context),
                      message: 'Import an EPUB or PDF to start reading',
                    )
                  : _BookGridWithRecents(
                      books: allBooks,
                      recentBooks: recentBooks,
                      onBookTap: (book) => _openBook(context, book),
                      onBookLongPress: (book) => _showBookOptions(context, book),
                    ),
              // Papers tab
              allPapers.isEmpty
                  ? _EmptyLibrary(
                      onImport: () => _importBook(context),
                      message: 'Import a PDF paper to start reading',
                      icon: Icons.article_outlined,
                    )
                  : _BookGrid(
                      books: allPapers,
                      onBookTap: (book) => _openBook(context, book),
                      onBookLongPress: (book) => _showBookOptions(context, book),
                    ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _importBook(context),
        backgroundColor: const Color(0xFF4a4660),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSyncIndicator(BuildContext context) {
    SyncService? syncService;
    try {
      syncService = context.watch<SyncService>();
    } catch (_) {
      // SyncService not provided — local-only mode
      return const SizedBox.shrink();
    }

    if (!syncService.available) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: Icon(Icons.cloud_off, size: 18, color: Colors.white24),
      );
    }

    if (syncService.syncing) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white38,
          ),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.only(right: 12),
      child: Icon(Icons.cloud_done_outlined, size: 18, color: Colors.white38),
    );
  }

  Future<void> _importBook(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf'],
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (!kIsWeb && file.path == null) return;
    if (!context.mounted) return;

    final library = context.read<LibraryService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Importing...'),
          duration: Duration(seconds: 1),
        ),
      );
      final book = await library.importBook(
        file.path ?? file.name,
        bytes: file.bytes,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('${book.isPaper ? "Paper" : "Book"} imported!')),
      );
      // Switch to the correct tab
      if (book.isPaper && _tabController.index != 1) {
        _tabController.animateTo(1);
      } else if (!book.isPaper && _tabController.index != 0) {
        _tabController.animateTo(0);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  void _openBook(BuildContext context, Book book) {
    context.read<LibraryService>().markOpened(book.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => book.isPdf
            ? PdfReaderScreen(book: book)
            : ReaderScreen(book: book),
      ),
    );
  }

  void _showBookOptions(BuildContext context, Book book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              book.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              book.author,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            if (book.isPdf) ...[
              const SizedBox(height: 4),
              Text(
                '${book.pageCount ?? "?"} pages  ·  ${book.isPaper ? "Paper" : "Book"}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            // Toggle category
            if (book.isPdf)
              ListTile(
                leading: Icon(
                  book.isPaper ? Icons.menu_book : Icons.article_outlined,
                  color: Colors.white70,
                ),
                title: Text(
                  book.isPaper ? 'Move to Books' : 'Move to Papers',
                  style: const TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final newCategory = book.isPaper
                      ? BookCategory.book
                      : BookCategory.paper;
                  context.read<LibraryService>().setCategory(book.id, newCategory);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Remove from library',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, book);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Remove?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "${book.title}" from your library? The file will be deleted.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<LibraryService>().removeBook(book.id);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  final VoidCallback onImport;
  final String message;
  final IconData icon;

  const _EmptyLibrary({
    required this.onImport,
    this.message = 'Import an EPUB or PDF to start reading',
    this.icon = Icons.auto_stories_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 72,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 24),
            Text(
              'Nothing here yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 18,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add),
              label: const Text('Import'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookGridWithRecents extends StatelessWidget {
  final List<Book> books;
  final List<Book> recentBooks;
  final void Function(Book) onBookTap;
  final void Function(Book) onBookLongPress;

  const _BookGridWithRecents({
    required this.books,
    required this.recentBooks,
    required this.onBookTap,
    required this.onBookLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Recent books horizontal row
        if (recentBooks.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Continue Reading',
                style: TextStyle(
                  color: const Color(0xFF2a2640).withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: recentBooks.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final book = recentBooks[index];
                  return SizedBox(
                    width: 100,
                    child: BookCard(
                      book: book,
                      onTap: () => onBookTap(book),
                      onLongPress: () => onBookLongPress(book),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'Library',
                style: TextStyle(
                  color: const Color(0xFF2a2640).withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
        // Full library grid
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final book = books[index];
                return BookCard(
                  book: book,
                  onTap: () => onBookTap(book),
                  onLongPress: () => onBookLongPress(book),
                );
              },
              childCount: books.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookGrid extends StatelessWidget {
  final List<Book> books;
  final void Function(Book) onBookTap;
  final void Function(Book) onBookLongPress;

  const _BookGrid({
    required this.books,
    required this.onBookTap,
    required this.onBookLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return BookCard(
          book: book,
          onTap: () => onBookTap(book),
          onLongPress: () => onBookLongPress(book),
        );
      },
    );
  }
}
