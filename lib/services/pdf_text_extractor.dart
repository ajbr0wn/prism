import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

/// A block of content extracted from a PDF page.
enum PdfBlockType { heading, paragraph, equation, figure, table, caption, listItem }

class PdfContentBlock {
  final PdfBlockType type;
  final String text;
  final double fontSize;
  final bool isBold;
  final bool isItalic;
  final int headingLevel; // 1-3 for headings, 0 otherwise
  final PdfRect bounds;
  final Uint8List? imageBytes; // For figure blocks

  const PdfContentBlock({
    required this.type,
    required this.text,
    this.fontSize = 12,
    this.isBold = false,
    this.isItalic = false,
    this.headingLevel = 0,
    required this.bounds,
    this.imageBytes,
  });
}

/// Extracts structured content from PDF pages, reconstructing
/// headings, paragraphs, equations, and figures.
class PdfTextExtractor {
  /// Extract structured content blocks from a single PDF page.
  static Future<List<PdfContentBlock>> extractPage(PdfPage page) async {
    final pageText = await page.loadText();
    final fragments = pageText.fragments;

    if (fragments.isEmpty) {
      // Page has no text — might be a scanned image
      return [
        PdfContentBlock(
          type: PdfBlockType.figure,
          text: '',
          bounds: PdfRect(0, page.height, page.width, 0),
          imageBytes: await _renderPageAsImage(page),
        ),
      ];
    }

    // Group fragments into lines based on vertical position
    final lines = _groupIntoLines(fragments, page.height);

    // Analyze font sizes to determine what's a heading vs body text
    final fontSizes = <double>[];
    for (final line in lines) {
      for (final frag in line.fragments) {
        final size = _estimateFontSize(frag);
        if (size > 0) fontSizes.add(size);
      }
    }
    fontSizes.sort();
    final bodyFontSize = fontSizes.isNotEmpty
        ? _median(fontSizes)
        : 10.0;

    // Build content blocks from lines
    final blocks = <PdfContentBlock>[];
    var currentParagraph = StringBuffer();
    PdfRect? paragraphBounds;
    var lastLineBottom = 0.0;

    for (final line in lines) {
      final lineText = line.text.trim();
      if (lineText.isEmpty) {
        // Empty line — flush current paragraph
        if (currentParagraph.isNotEmpty) {
          blocks.add(PdfContentBlock(
            type: PdfBlockType.paragraph,
            text: currentParagraph.toString().trim(),
            fontSize: bodyFontSize,
            bounds: paragraphBounds ?? line.bounds,
          ));
          currentParagraph.clear();
          paragraphBounds = null;
        }
        continue;
      }

      final lineFontSize = _estimateLineFontSize(line);
      final lineIsBold = _lineIsBold(line);

      // Check for equations — lines with many math symbols or LaTeX patterns
      if (looksLikeEquation(lineText)) {
        // Flush paragraph first
        if (currentParagraph.isNotEmpty) {
          blocks.add(PdfContentBlock(
            type: PdfBlockType.paragraph,
            text: currentParagraph.toString().trim(),
            fontSize: bodyFontSize,
            bounds: paragraphBounds ?? line.bounds,
          ));
          currentParagraph.clear();
          paragraphBounds = null;
        }

        blocks.add(PdfContentBlock(
          type: PdfBlockType.equation,
          text: cleanEquationText(lineText),
          fontSize: lineFontSize,
          bounds: line.bounds,
        ));
        continue;
      }

      // Check for headings — significantly larger text or bold short lines
      final sizeRatio = lineFontSize / bodyFontSize;
      if (sizeRatio > 1.25 || (lineIsBold && lineText.length < 80)) {
        // Flush paragraph first
        if (currentParagraph.isNotEmpty) {
          blocks.add(PdfContentBlock(
            type: PdfBlockType.paragraph,
            text: currentParagraph.toString().trim(),
            fontSize: bodyFontSize,
            bounds: paragraphBounds ?? line.bounds,
          ));
          currentParagraph.clear();
          paragraphBounds = null;
        }

        int level;
        if (sizeRatio > 1.6) {
          level = 1;
        } else if (sizeRatio > 1.3) {
          level = 2;
        } else {
          level = 3;
        }

        blocks.add(PdfContentBlock(
          type: PdfBlockType.heading,
          text: lineText,
          fontSize: lineFontSize,
          isBold: lineIsBold,
          headingLevel: level,
          bounds: line.bounds,
        ));
        continue;
      }

      // Check for list items
      if (looksLikeListItem(lineText)) {
        if (currentParagraph.isNotEmpty) {
          blocks.add(PdfContentBlock(
            type: PdfBlockType.paragraph,
            text: currentParagraph.toString().trim(),
            fontSize: bodyFontSize,
            bounds: paragraphBounds ?? line.bounds,
          ));
          currentParagraph.clear();
          paragraphBounds = null;
        }

        blocks.add(PdfContentBlock(
          type: PdfBlockType.listItem,
          text: lineText,
          fontSize: bodyFontSize,
          bounds: line.bounds,
        ));
        continue;
      }

      // Check for figure captions
      if (looksLikeCaption(lineText)) {
        if (currentParagraph.isNotEmpty) {
          blocks.add(PdfContentBlock(
            type: PdfBlockType.paragraph,
            text: currentParagraph.toString().trim(),
            fontSize: bodyFontSize,
            bounds: paragraphBounds ?? line.bounds,
          ));
          currentParagraph.clear();
          paragraphBounds = null;
        }

        blocks.add(PdfContentBlock(
          type: PdfBlockType.caption,
          text: lineText,
          fontSize: bodyFontSize,
          isItalic: true,
          bounds: line.bounds,
        ));
        continue;
      }

      // Regular body text — check for paragraph breaks
      // A new paragraph starts if there's a significant vertical gap
      final verticalGap = (line.bounds.top - lastLineBottom).abs();
      final lineHeight = (line.bounds.top - line.bounds.bottom).abs();
      final gapRatio = lineHeight > 0 ? verticalGap / lineHeight : 0;

      if (gapRatio > 1.5 && currentParagraph.isNotEmpty) {
        // Significant gap — new paragraph
        blocks.add(PdfContentBlock(
          type: PdfBlockType.paragraph,
          text: currentParagraph.toString().trim(),
          fontSize: bodyFontSize,
          bounds: paragraphBounds ?? line.bounds,
        ));
        currentParagraph.clear();
        paragraphBounds = null;
      }

      // Append to current paragraph
      if (currentParagraph.isNotEmpty) {
        // Check if previous line ended mid-word (hyphenation)
        final prev = currentParagraph.toString();
        if (prev.endsWith('-')) {
          // Remove hyphen and join directly
          currentParagraph.clear();
          currentParagraph.write(prev.substring(0, prev.length - 1));
        } else {
          currentParagraph.write(' ');
        }
      }
      currentParagraph.write(lineText);
      paragraphBounds = paragraphBounds == null
          ? line.bounds
          : PdfRect(
              paragraphBounds.left < line.bounds.left
                  ? paragraphBounds.left
                  : line.bounds.left,
              paragraphBounds.top > line.bounds.top
                  ? paragraphBounds.top
                  : line.bounds.top,
              paragraphBounds.right > line.bounds.right
                  ? paragraphBounds.right
                  : line.bounds.right,
              paragraphBounds.bottom < line.bounds.bottom
                  ? paragraphBounds.bottom
                  : line.bounds.bottom,
            );

      lastLineBottom = line.bounds.bottom;
    }

    // Flush remaining paragraph
    if (currentParagraph.isNotEmpty) {
      blocks.add(PdfContentBlock(
        type: PdfBlockType.paragraph,
        text: currentParagraph.toString().trim(),
        fontSize: bodyFontSize,
        bounds: paragraphBounds!,
      ));
    }

    return blocks;
  }

  /// Extract structured content from all pages of a document.
  static Future<List<List<PdfContentBlock>>> extractDocument(
    PdfDocument doc,
  ) async {
    final pages = <List<PdfContentBlock>>[];
    for (final page in doc.pages) {
      pages.add(await extractPage(page));
    }
    return pages;
  }

  /// Render a region of a page as a PNG image.
  static Future<Uint8List?> renderPageRegion(
    PdfPage page,
    PdfRect region, {
    double scale = 2.0,
  }) async {
    try {
      final regionWidth = (region.right - region.left).abs();
      final regionHeight = (region.top - region.bottom).abs();
      if (regionWidth <= 0 || regionHeight <= 0) return null;

      final fullWidth = page.width * scale;
      final fullHeight = page.height * scale;

      final pdfImage = await page.render(
        x: (region.left * scale).round(),
        y: ((page.height - region.top) * scale).round(),
        width: (regionWidth * scale).round(),
        height: (regionHeight * scale).round(),
        fullWidth: fullWidth,
        fullHeight: fullHeight,
      );
      if (pdfImage == null) return null;

      final uiImage = await pdfImage.createImage();
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Failed to render page region: $e');
      return null;
    }
  }

  /// Render an entire page as a PNG image.
  static Future<Uint8List?> _renderPageAsImage(PdfPage page) async {
    try {
      final scale = 2.0;
      final pdfImage = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
      );
      if (pdfImage == null) return null;

      final uiImage = await pdfImage.createImage();
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Failed to render page as image: $e');
      return null;
    }
  }

  // ── Line grouping ──

  static List<_TextLine> _groupIntoLines(
    List<PdfPageTextFragment> fragments,
    double pageHeight,
  ) {
    if (fragments.isEmpty) return [];

    // Sort fragments by vertical position (top of page first)
    final sorted = List<PdfPageTextFragment>.from(fragments)
      ..sort((a, b) {
        // PDF coordinates: y=0 is bottom, higher y is higher on page
        final yDiff = b.bounds.top.compareTo(a.bounds.top);
        if (yDiff != 0) return yDiff;
        return a.bounds.left.compareTo(b.bounds.left);
      });

    final lines = <_TextLine>[];
    var currentLine = <PdfPageTextFragment>[sorted.first];
    var currentTop = sorted.first.bounds.top;
    var currentBottom = sorted.first.bounds.bottom;

    for (var i = 1; i < sorted.length; i++) {
      final frag = sorted[i];
      final fragMidY = (frag.bounds.top + frag.bounds.bottom) / 2;

      // Same line if the vertical midpoint falls within the current line bounds
      if (fragMidY <= currentTop && fragMidY >= currentBottom) {
        currentLine.add(frag);
      } else {
        // New line
        lines.add(_TextLine(currentLine));
        currentLine = [frag];
        currentTop = frag.bounds.top;
        currentBottom = frag.bounds.bottom;
      }
    }
    if (currentLine.isNotEmpty) {
      lines.add(_TextLine(currentLine));
    }

    return lines;
  }

  // ── Font analysis ──

  static double _estimateFontSize(PdfPageTextFragment frag) {
    final height = (frag.bounds.top - frag.bounds.bottom).abs();
    return height > 0 ? height : 0;
  }

  static double _estimateLineFontSize(_TextLine line) {
    if (line.fragments.isEmpty) return 0;
    var totalSize = 0.0;
    var count = 0;
    for (final frag in line.fragments) {
      final size = _estimateFontSize(frag);
      if (size > 0) {
        totalSize += size;
        count++;
      }
    }
    return count > 0 ? totalSize / count : 0;
  }

  static bool _lineIsBold(_TextLine line) {
    // Heuristic: bold text tends to have wider character bounding boxes
    // relative to height. This is a rough approximation since pdfrx
    // doesn't expose font weight directly.
    // We check if the text looks like a section header pattern.
    final text = line.text.trim();
    // Common academic paper heading patterns
    if (RegExp(r'^\d+\.?\s+[A-Z]').hasMatch(text)) return true;
    if (RegExp(r'^[A-Z][A-Z\s]+$').hasMatch(text) && text.length < 60) return true;
    if (RegExp(r'^(Abstract|Introduction|Conclusion|References|Acknowledgments|Appendix)',
            caseSensitive: false)
        .hasMatch(text)) return true;
    return false;
  }

  static double _median(List<double> sorted) {
    if (sorted.isEmpty) return 0;
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  // ── Content detection ──

  /// Detect if a line looks like a mathematical equation.
  static bool looksLikeEquation(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // LaTeX delimiters
    if (trimmed.startsWith(r'\[') || trimmed.startsWith(r'$$')) return true;
    if (trimmed.startsWith(r'\begin{equation')) return true;
    if (trimmed.startsWith(r'\begin{align')) return true;

    // High density of math symbols
    final mathChars = RegExp(r'[=+\-×÷∫∑∏√∂∇∞≈≠≤≥±∈∉⊂⊃∪∩∀∃αβγδεζηθλμξπρσφψω]');
    final mathCount = mathChars.allMatches(trimmed).length;
    final ratio = mathCount / trimmed.length;

    // Standalone equation patterns: centered short lines with math
    if (ratio > 0.15 && trimmed.length < 120) return true;

    // Lines that are mostly symbols/numbers with operators
    if (RegExp(r'^[\s\d\w=+\-*/^{}()\[\]\\.,|<>]+$').hasMatch(trimmed) &&
        trimmed.contains('=') &&
        trimmed.length < 100 &&
        !trimmed.contains('. ')) {
      return true;
    }

    return false;
  }

  /// Try to clean up extracted equation text into something renderable.
  static String cleanEquationText(String text) {
    var cleaned = text.trim();
    // Remove equation numbers like (1), (2.3)
    cleaned = cleaned.replaceAll(RegExp(r'\(\d+\.?\d*\)\s*$'), '').trim();
    return cleaned;
  }

  /// Detect list items.
  static bool looksLikeListItem(String text) {
    final trimmed = text.trim();
    // Bullet points, numbered lists, dashes
    return RegExp(r'^[•\-–—]\s').hasMatch(trimmed) ||
        RegExp(r'^\d+[.)]\s').hasMatch(trimmed) ||
        RegExp(r'^[a-z][.)]\s').hasMatch(trimmed) ||
        RegExp(r'^[ivxIVX]+[.)]\s').hasMatch(trimmed);
  }

  /// Detect figure/table captions.
  static bool looksLikeCaption(String text) {
    final trimmed = text.trim();
    return RegExp(r'^(Figure|Fig\.|Table|Listing|Algorithm)\s+\d', caseSensitive: false)
        .hasMatch(trimmed);
  }
}

/// A group of text fragments on the same line.
class _TextLine {
  final List<PdfPageTextFragment> fragments;
  late final String text;
  late final PdfRect bounds;

  _TextLine(this.fragments) {
    // Sort left to right
    fragments.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

    // Build text
    final buffer = StringBuffer();
    for (final frag in fragments) {
      final fragText = frag.text;
      if (buffer.isNotEmpty && !buffer.toString().endsWith(' ') && !fragText.startsWith(' ')) {
        buffer.write(' ');
      }
      buffer.write(fragText);
    }
    text = buffer.toString();

    // Calculate bounds
    var left = double.infinity;
    var right = double.negativeInfinity;
    var top = double.negativeInfinity;
    var bottom = double.infinity;
    for (final frag in fragments) {
      if (frag.bounds.left < left) left = frag.bounds.left;
      if (frag.bounds.right > right) right = frag.bounds.right;
      if (frag.bounds.top > top) top = frag.bounds.top;
      if (frag.bounds.bottom < bottom) bottom = frag.bounds.bottom;
    }
    bounds = PdfRect(left, top, right, bottom);
  }
}
