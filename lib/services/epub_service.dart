import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models/book.dart';

class EpubService {
  /// Parse an EPUB file into structured content.
  static Future<ParsedEpub> parse(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Read container.xml to find the root file
    final containerBytes = _findFile(archive, 'META-INF/container.xml');
    if (containerBytes == null) {
      throw FormatException('Invalid EPUB: missing META-INF/container.xml');
    }

    final containerXml = XmlDocument.parse(utf8.decode(containerBytes));
    final rootFilePath = containerXml
        .findAllElements('rootfile')
        .first
        .getAttribute('full-path');
    if (rootFilePath == null) {
      throw FormatException('Invalid EPUB: no rootfile path found');
    }

    // 2. Parse the root file (content.opf)
    final rootBytes = _findFile(archive, rootFilePath);
    if (rootBytes == null) {
      throw FormatException('Invalid EPUB: missing root file $rootFilePath');
    }

    final rootXml = XmlDocument.parse(utf8.decode(rootBytes));
    final baseDir = rootFilePath.contains('/')
        ? rootFilePath.substring(0, rootFilePath.lastIndexOf('/') + 1)
        : '';

    // 3. Extract metadata
    final metadata = rootXml.findAllElements('metadata').firstOrNull;
    final title = _getMetaValue(metadata, 'title') ?? 'Unknown Title';
    final author = _getMetaValue(metadata, 'creator') ?? 'Unknown Author';

    // 4. Build manifest (id -> href, id -> media-type)
    final manifestHref = <String, String>{};
    final manifestType = <String, String>{};
    for (final item in rootXml.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      final mediaType = item.getAttribute('media-type');
      if (id != null && href != null) {
        manifestHref[id] = href;
        if (mediaType != null) manifestType[id] = mediaType;
      }
    }

    // 5. Get spine (reading order)
    final spineIds = <String>[];
    for (final itemref in rootXml.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      if (idref != null) spineIds.add(idref);
    }

    // 6. Extract chapters in reading order
    final chapters = <EpubChapter>[];
    for (final itemId in spineIds) {
      final href = manifestHref[itemId];
      if (href == null) continue;

      final fullPath = baseDir + href;
      final fileBytes = _findFile(archive, fullPath);
      if (fileBytes == null) continue;

      final content = utf8.decode(fileBytes, allowMalformed: true);
      final chapterTitle = _extractChapterTitle(content) ??
          'Chapter ${chapters.length + 1}';

      chapters.add(EpubChapter(title: chapterTitle, content: content));
    }

    // 7. Try to extract cover image
    List<int>? coverBytes;

    // Look for cover in metadata
    final coverMeta = metadata?.findAllElements('meta').where(
        (m) => m.getAttribute('name') == 'cover');
    if (coverMeta != null && coverMeta.isNotEmpty) {
      final coverId = coverMeta.first.getAttribute('content');
      if (coverId != null && manifestHref.containsKey(coverId)) {
        final coverPath = baseDir + manifestHref[coverId]!;
        coverBytes = _findFile(archive, coverPath);
      }
    }

    // Fallback: look for an image with "cover" in the filename
    if (coverBytes == null) {
      for (final entry in manifestHref.entries) {
        final type = manifestType[entry.key] ?? '';
        if (type.startsWith('image/') &&
            entry.value.toLowerCase().contains('cover')) {
          final coverPath = baseDir + entry.value;
          coverBytes = _findFile(archive, coverPath);
          if (coverBytes != null) break;
        }
      }
    }

    return ParsedEpub(
      title: title,
      author: author,
      chapters: chapters,
      coverImageBytes: coverBytes,
    );
  }

  static List<int>? _findFile(Archive archive, String name) {
    // Try exact match first, then case-insensitive
    for (final file in archive) {
      if (file.isFile && file.name == name) {
        return file.content as List<int>;
      }
    }
    final lower = name.toLowerCase();
    for (final file in archive) {
      if (file.isFile && file.name.toLowerCase() == lower) {
        return file.content as List<int>;
      }
    }
    return null;
  }

  static String? _getMetaValue(XmlElement? metadata, String localName) {
    if (metadata == null) return null;
    for (final child in metadata.childElements) {
      if (child.localName == localName) {
        final text = child.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  static String? _extractChapterTitle(String xhtml) {
    try {
      final doc = XmlDocument.parse(xhtml);
      // Try h1, h2, h3, then title
      for (final tag in ['h1', 'h2', 'h3']) {
        final el = doc.findAllElements(tag).firstOrNull;
        if (el != null) {
          final text = el.innerText.trim();
          if (text.isNotEmpty) return text;
        }
      }
      final titleEl = doc.findAllElements('title').firstOrNull;
      if (titleEl != null) {
        final text = titleEl.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    } catch (_) {
      // If parsing fails, that's fine - we'll use default title
    }
    return null;
  }
}
