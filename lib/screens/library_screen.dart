import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/library_service.dart';
import '../widgets/book_card.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

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
      ),
      body: Consumer<LibraryService>(
        builder: (context, library, child) {
          if (!library.initialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white24),
            );
          }

          if (library.books.isEmpty) {
            return _EmptyLibrary(onImport: () => _importBook(context));
          }

          return _BookGrid(
            books: library.books,
            onBookTap: (book) => _openBook(context, book),
            onBookLongPress: (book) => _showBookOptions(context, book),
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

  Future<void> _importBook(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );

    if (result == null || result.files.single.path == null) return;
    if (!context.mounted) return;

    final library = context.read<LibraryService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Importing book...'),
          duration: Duration(seconds: 1),
        ),
      );
      await library.importBook(result.files.single.path!);
      messenger.showSnackBar(
        const SnackBar(content: Text('Book imported!')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  void _openBook(BuildContext context, Book book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(book: book),
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
            const SizedBox(height: 16),
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
        title: const Text('Remove book?', style: TextStyle(color: Colors.white)),
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

  const _EmptyLibrary({required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 72,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 24),
            Text(
              'Your library is empty',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 18,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Import an EPUB to start reading',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add),
              label: const Text('Import Book'),
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
