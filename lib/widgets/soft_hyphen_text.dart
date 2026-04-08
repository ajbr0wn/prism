import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/rendering.dart';

/// Fixes Flutter's soft hyphen rendering bug (flutter/flutter#18443).
///
/// Flutter's text engine breaks lines at soft hyphens (\u00AD) but never
/// renders the visible hyphen glyph. This widget detects which soft hyphens
/// land at line breaks by inspecting the ACTUAL render tree after the first
/// frame, then rebuilds with visible '-' at those positions.
///
/// Why inspect the render tree? Creating a separate TextPainter and calling
/// its line-detection APIs (getLineBoundary, getPositionForOffset,
/// getBoxesForSelection) all fail on real Android — the separately-created
/// TextPainter doesn't produce the same line breaks as the actual widget.
/// Only the real render object has the correct layout.
class SoftHyphenText extends StatefulWidget {
  final TextSpan textSpan;
  final TextAlign textAlign;
  final Widget Function(BuildContext, EditableTextState)? contextMenuBuilder;

  const SoftHyphenText({
    super.key,
    required this.textSpan,
    required this.textAlign,
    this.contextMenuBuilder,
  });

  @override
  State<SoftHyphenText> createState() => SoftHyphenTextState();
}

class SoftHyphenTextState extends State<SoftHyphenText> {
  final _measureKey = GlobalKey();
  TextSpan? _processedSpan;
  double? _lastWidth;
  Set<int> _lastBreakPositions = {};

  // Cache processed spans so recycled widgets don't re-measure and jump.
  // Key: plain text + width string. Using full text avoids hash collisions
  // that caused wrong styles to be served across paragraphs.
  static final _cache = <String, ({TextSpan span, Set<int> breaks})>{};
  static const _maxCacheSize = 200;

  /// Pre-measure all soft hyphen break positions for a list of TextSpans
  /// at a given width. Populates the static cache so that when the widgets
  /// build, they already have the correct hyphens — no jump, no flash.
  ///
  /// Call this during the chapter loading phase before rendering.
  /// Uses TextPainter which may differ slightly from RenderEditable
  /// on some devices — the post-frame pass will silently correct any
  /// mismatches.
  static void preMeasure(
    List<TextSpan> spans,
    double width,
    TextAlign textAlign,
  ) {
    for (final span in spans) {
      final plainText = span.toPlainText();
      if (!plainText.contains('\u00AD')) continue;

      final cacheKey = '$plainText@$width';
      if (_cache.containsKey(cacheKey)) continue;

      final tp = TextPainter(
        text: span,
        textAlign: textAlign,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);

      final softHyphenBreaks = <int>{};
      for (var i = 0; i < plainText.length; i++) {
        if (plainText[i] != '\u00AD') continue;
        if (i == 0 || i + 1 >= plainText.length) continue;

        final beforeBoxes = tp.getBoxesForSelection(
          TextSelection(baseOffset: i - 1, extentOffset: i),
        );
        final afterBoxes = tp.getBoxesForSelection(
          TextSelection(baseOffset: i + 1, extentOffset: i + 2),
        );

        if (beforeBoxes.isNotEmpty && afterBoxes.isNotEmpty) {
          final beforeBottom = beforeBoxes.last.bottom;
          final afterTop = afterBoxes.first.top;
          if (afterTop >= beforeBottom - 1) {
            softHyphenBreaks.add(i);
          }
        }
      }

      tp.dispose();

      if (softHyphenBreaks.isEmpty) continue;

      final processed = _replaceInSpan(span, softHyphenBreaks, 0).span;
      if (_cache.length >= _maxCacheSize) {
        _cache.remove(_cache.keys.first);
      }
      _cache[cacheKey] = (span: processed, breaks: softHyphenBreaks);
    }
  }

  /// The span after soft hyphen replacement, or null if not yet processed.
  @visibleForTesting
  TextSpan? get processedSpan => _processedSpan;

  /// Character offsets where soft hyphens were placed at line breaks.
  @visibleForTesting
  Set<int> get breakPositions => _lastBreakPositions;

  @override
  void initState() {
    super.initState();
    _tryCache();
    _scheduleMeasure();
  }

  /// Check cache for a pre-measured result at any width.
  /// If found, use it immediately — avoids the two-phase jump.
  void _tryCache() {
    final plainText = widget.textSpan.toPlainText();
    if (!plainText.contains('\u00AD')) return;
    for (final entry in _cache.entries) {
      if (entry.key.startsWith('$plainText@')) {
        _processedSpan = entry.value.span;
        _lastBreakPositions = entry.value.breaks;
        // Extract width from cache key
        final widthStr = entry.key.substring(plainText.length + 1);
        _lastWidth = double.tryParse(widthStr);
        return;
      }
    }
  }

  @override
  void didUpdateWidget(SoftHyphenText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textSpan != widget.textSpan ||
        oldWidget.textAlign != widget.textAlign) {
      _processedSpan = null;
      _lastWidth = null;
      _scheduleMeasure();
    }
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndFix());
  }

  void _measureAndFix() {
    if (!mounted) return;
    final ctx = _measureKey.currentContext;
    if (ctx == null) return;
    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final width = renderBox.size.width;
    if (width <= 0) return;

    // Width unchanged — no need to re-measure.
    if (width == _lastWidth) return;

    // Width changed (e.g. margin settings changed) — need to re-measure.
    // Clear stale results and schedule a re-measure after rebuilding
    // with the original text (so line breaks are correct for new width).
    if (_lastWidth != null && _processedSpan != null) {
      setState(() {
        _processedSpan = null;
        _lastBreakPositions = {};
        _lastWidth = null;
      });
      _scheduleMeasure();
      return;
    }

    final plainText = widget.textSpan.toPlainText();
    if (!plainText.contains('\u00AD')) return;

    // Check cache first — avoids re-measurement and the visible jump
    // when widgets are recycled during scrolling.
    final cacheKey = '$plainText@$width';
    final cached = _cache[cacheKey];
    if (cached != null) {
      _lastBreakPositions = cached.breaks;
      _lastWidth = width;
      // Only rebuild if the span actually changed
      if (!identical(_processedSpan, cached.span)) {
        if (!mounted) return;
        setState(() => _processedSpan = cached.span);
      }
      return;
    }

    // Find the actual RenderEditable in the render tree.
    final renderEditable = _findRenderEditable(renderBox);
    if (renderEditable == null) return;

    final softHyphenBreaks = <int>{};

    for (var i = 0; i < plainText.length; i++) {
      if (plainText[i] != '\u00AD') continue;
      if (i == 0 || i + 1 >= plainText.length) continue;

      final beforeBoxes = renderEditable.getBoxesForSelection(
        TextSelection(baseOffset: i - 1, extentOffset: i),
      );
      final afterBoxes = renderEditable.getBoxesForSelection(
        TextSelection(baseOffset: i + 1, extentOffset: i + 2),
      );

      if (beforeBoxes.isNotEmpty && afterBoxes.isNotEmpty) {
        final beforeBottom = beforeBoxes.last.bottom;
        final afterTop = afterBoxes.first.top;
        if (afterTop >= beforeBottom - 1) {
          softHyphenBreaks.add(i);
        }
      }
    }

    _lastBreakPositions = softHyphenBreaks;
    _lastWidth = width;

    if (softHyphenBreaks.isEmpty) return;

    final processed = _replaceInSpan(widget.textSpan, softHyphenBreaks, 0).span;

    // Cache the result.
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = (span: processed, breaks: softHyphenBreaks);

    if (!mounted) return;
    setState(() {
      _processedSpan = processed;
      _lastWidth = width;
    });
  }

  /// Walk the render tree to find the RenderEditable (used by SelectableText).
  static RenderEditable? _findRenderEditable(RenderObject root) {
    if (root is RenderEditable) return root;
    RenderEditable? result;
    root.visitChildren((child) {
      result ??= _findRenderEditable(child);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // Always render — the original text with \u00AD is nearly identical
    // to the processed text since \u00AD is invisible/zero-width.
    // No more Visibility hiding = no more flash on scroll.
    return SelectableText.rich(
      _processedSpan ?? widget.textSpan,
      key: _measureKey,
      textAlign: widget.textAlign,
      contextMenuBuilder: widget.contextMenuBuilder,
    );
  }

  /// Walk the TextSpan tree and process soft hyphens:
  /// - At break positions: replace \u00AD with visible '-'
  /// - Elsewhere: strip \u00AD entirely
  ///
  /// Offsets are in the original (pre-replacement) plain text coordinates.
  static ({TextSpan span, int offset}) _replaceInSpan(
    TextSpan span,
    Set<int> breakPositions,
    int offset,
  ) {
    String? processedText;
    var textEnd = offset;
    if (span.text != null) {
      final text = span.text!;
      textEnd = offset + text.length;

      // Only replace soft hyphens at break positions with visible '-'.
      // Leave non-break soft hyphens as-is to minimize text change and
      // avoid the visible layout jump when the widget rebuilds.
      bool hasBreak = false;
      for (var i = 0; i < text.length; i++) {
        if (text[i] == '\u00AD' && breakPositions.contains(offset + i)) {
          hasBreak = true;
          break;
        }
      }

      if (hasBreak) {
        final buf = StringBuffer();
        for (var i = 0; i < text.length; i++) {
          if (text[i] == '\u00AD' && breakPositions.contains(offset + i)) {
            buf.write('-');
          } else {
            buf.write(text[i]);
          }
        }
        processedText = buf.toString();
      }
    }

    List<InlineSpan>? processedChildren;
    var childOffset = textEnd;
    if (span.children != null) {
      var anyChildChanged = false;
      final newChildren = <InlineSpan>[];

      for (final child in span.children!) {
        if (child is TextSpan) {
          final result = _replaceInSpan(child, breakPositions, childOffset);
          newChildren.add(result.span);
          if (!identical(result.span, child)) anyChildChanged = true;
          childOffset = result.offset;
        } else {
          newChildren.add(child);
          childOffset += 1;
        }
      }

      if (anyChildChanged) {
        processedChildren = newChildren;
      }
    }

    if (processedText == null && processedChildren == null) {
      return (span: span, offset: childOffset);
    }

    return (
      span: TextSpan(
        text: processedText ?? span.text,
        style: span.style,
        children: processedChildren ?? span.children,
        recognizer: span.recognizer,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
      ),
      offset: childOffset,
    );
  }
}
