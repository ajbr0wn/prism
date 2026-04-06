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
  // Key: plain text hashcode ^ width hashcode. Value: processed span + breaks.
  static final _cache = <int, ({TextSpan span, Set<int> breaks})>{};
  static const _maxCacheSize = 200;

  /// The span after soft hyphen replacement, or null if not yet processed.
  @visibleForTesting
  TextSpan? get processedSpan => _processedSpan;

  /// Character offsets where soft hyphens were placed at line breaks.
  @visibleForTesting
  Set<int> get breakPositions => _lastBreakPositions;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
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
    if (width <= 0 || width == _lastWidth) return;

    final plainText = widget.textSpan.toPlainText();
    if (!plainText.contains('\u00AD')) return;

    // Check cache first — avoids re-measurement and the visible jump
    // when widgets are recycled during scrolling.
    final cacheKey = plainText.hashCode ^ width.hashCode;
    final cached = _cache[cacheKey];
    if (cached != null) {
      _lastBreakPositions = cached.breaks;
      if (!mounted) return;
      setState(() {
        _processedSpan = cached.span;
        _lastWidth = width;
      });
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

      bool hasSoftHyphens = false;
      for (var i = 0; i < text.length; i++) {
        if (text[i] == '\u00AD') {
          hasSoftHyphens = true;
          break;
        }
      }

      if (hasSoftHyphens) {
        final buf = StringBuffer();
        for (var i = 0; i < text.length; i++) {
          if (text[i] == '\u00AD') {
            if (breakPositions.contains(offset + i)) {
              buf.write('-');
            }
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
