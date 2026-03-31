import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/book.dart';

/// Syncs library state and book files to Firebase for persistence
/// across installs. Single-user — no auth, uses a fixed document path.
///
/// Gracefully degrades to no-op when Firebase isn't configured.
class SyncService extends ChangeNotifier {
  static const _libraryDoc = 'users/default/library/state';
  static const _booksPrefix = 'books/';

  bool _available = false;
  bool _syncing = false;
  String? _lastError;

  bool get available => _available;
  bool get syncing => _syncing;
  String? get lastError => _lastError;

  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;

  /// Initialize sync. Returns true if Firebase is available.
  Future<bool> init() async {
    try {
      _firestore = FirebaseFirestore.instance;
      _storage = FirebaseStorage.instance;
      // Test connectivity with a simple read
      await _firestore!.doc(_libraryDoc).get();
      _available = true;
      debugPrint('SyncService: Firebase connected');
    } catch (e) {
      _available = false;
      debugPrint('SyncService: Firebase not available ($e)');
    }
    notifyListeners();
    return _available;
  }

  /// Upload a book file to cloud storage.
  /// Returns the storage path, or null on failure.
  Future<String?> uploadBook(String localPath) async {
    if (!_available) return null;

    try {
      _syncing = true;
      _lastError = null;
      notifyListeners();

      final file = File(localPath);
      final fileName = localPath.split('/').last;
      final storagePath = '$_booksPrefix$fileName';

      final ref = _storage!.ref(storagePath);
      await ref.putFile(file);

      _syncing = false;
      notifyListeners();
      return storagePath;
    } catch (e) {
      _lastError = 'Upload failed: $e';
      _syncing = false;
      notifyListeners();
      debugPrint('SyncService: $e');
      return null;
    }
  }

  /// Download a book file from cloud storage to local path.
  Future<bool> downloadBook(String storagePath, String localPath) async {
    if (!_available) return false;

    try {
      _syncing = true;
      notifyListeners();

      final ref = _storage!.ref(storagePath);
      final file = File(localPath);
      await file.create(recursive: true);
      await ref.writeToFile(file);

      _syncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Download failed: $e';
      _syncing = false;
      notifyListeners();
      debugPrint('SyncService: $e');
      return false;
    }
  }

  /// Upload a cover image to cloud storage.
  Future<String?> uploadCover(String localPath) async {
    if (!_available) return null;

    try {
      final file = File(localPath);
      final fileName = localPath.split('/').last;
      final storagePath = 'covers/$fileName';

      final ref = _storage!.ref(storagePath);
      await ref.putFile(file);
      return storagePath;
    } catch (e) {
      debugPrint('SyncService: cover upload failed: $e');
      return null;
    }
  }

  /// Save the full library state to Firestore.
  Future<void> saveLibrary(List<Book> books) async {
    if (!_available) return;

    try {
      _syncing = true;
      _lastError = null;
      notifyListeners();

      final data = {
        'books': books.map((b) => b.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore!.doc(_libraryDoc).set(data);

      _syncing = false;
      notifyListeners();
    } catch (e) {
      _lastError = 'Sync failed: $e';
      _syncing = false;
      notifyListeners();
      debugPrint('SyncService: $e');
    }
  }

  /// Load library state from Firestore.
  /// Returns null if no remote state exists.
  Future<List<Book>?> loadLibrary() async {
    if (!_available) return null;

    try {
      _syncing = true;
      notifyListeners();

      final doc = await _firestore!.doc(_libraryDoc).get();

      _syncing = false;
      notifyListeners();

      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      final booksList = data['books'] as List<dynamic>?;
      if (booksList == null) return null;

      return booksList
          .map((item) => Book.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _lastError = 'Load failed: $e';
      _syncing = false;
      notifyListeners();
      debugPrint('SyncService: $e');
      return null;
    }
  }

  /// Restore books from cloud that aren't on this device.
  /// Downloads missing book files and returns the merged library.
  Future<List<Book>> restoreMissingBooks(
    List<Book> localBooks,
    List<Book> remoteBooks,
  ) async {
    if (!_available) return localBooks;

    final dir = await getApplicationDocumentsDirectory();
    final booksDir = '${dir.path}/prism/books';
    final coversDir = '${dir.path}/prism/covers';
    await Directory(booksDir).create(recursive: true);
    await Directory(coversDir).create(recursive: true);

    final localIds = localBooks.map((b) => b.id).toSet();
    final merged = List<Book>.from(localBooks);

    for (final remoteBook in remoteBooks) {
      if (localIds.contains(remoteBook.id)) continue;

      // Download the book file
      final fileName = remoteBook.filePath.split('/').last;
      final localPath = '$booksDir/$fileName';
      final storagePath = '$_booksPrefix$fileName';

      final success = await downloadBook(storagePath, localPath);
      if (!success) continue;

      // Download cover if available
      String? localCoverPath;
      if (remoteBook.coverPath != null) {
        final coverFileName = remoteBook.coverPath!.split('/').last;
        localCoverPath = '$coversDir/$coverFileName';
        await downloadBook('covers/$coverFileName', localCoverPath);
      }

      merged.add(remoteBook.copyWith(
        filePath: localPath,
        coverPath: localCoverPath,
      ));
    }

    return merged;
  }

  /// Listen for real-time library changes from Firestore.
  Stream<List<Book>?>? watchLibrary() {
    if (!_available) return null;

    return _firestore!.doc(_libraryDoc).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      final booksList = snap.data()!['books'] as List<dynamic>?;
      if (booksList == null) return null;
      return booksList
          .map((item) => Book.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }
}
