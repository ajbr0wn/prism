import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Fixes Flutter's soft hyphen rendering bug (flutter/flutter#18443).
///
/// Flutter's text engine breaks lines at soft hyphens (\u00AD) but never
/// renders the visible hyphen glyph. This widget computes its own line
/// breaks using single-line width measurement, then replaces soft hyphens
/// at break points with visible '-' and strips the rest.
///
/// Why not use TextPainter's line boundary APIs? getLineBoundary and
/// getPositionForOffset work in widget tests but fail on real Android
/// devices — the text shaper reports incorrect boundaries for zero-width
/// soft hyphens. Single-line width measurement (getOffsetForCaret on a
/// maxWidth=infinity layout) IS reliable everywhere.
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

    final processed = _fixSoftHyphens(width);
    if (!mounted) return;
    setState(() {
      _processedSpan = processed;
      _lastWidth = width;
    });
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

  TextSpan _fixSoftHyphens(double maxWidth) {
    final plainText = widget.textSpan.toPlainText();
    if (!plainText.contains('\u00AD')) return widget.textSpan;

    final textScaler = MediaQuery.textScalerOf(context);

    // Layout MULTI-LINE at the actual width — Flutter will break lines
    // correctly (including at soft hyphens for better justification).
    // Then detect which soft hyphens landed at breaks by comparing the
    // y-coordinates of adjacent visible characters via getBoxesForSelection.
    //
    // Previous approaches that FAILED on real Android:
    // - getLineBoundary: returns wrong boundaries for zero-width soft hyphens
    // - getPositionForOffset: misses zero-width characters at line edges
    // - Own line breaking via single-line measurement: computes different
    //   breaks than Flutter's engine (spaces preferred over soft hyphens)
    //
    // getBoxesForSelection returns actual rendered box positions from the
    // laid-out paragraph — it's the same API used for text selection handles,
    // so it's reliable on all platforms.
    final painter = TextPainter(
      text: widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    );
    painter.layout(maxWidth: maxWidth);

    final softHyphenBreaks = <int>{};

    for (var i = 0; i < plainText.length; i++) {
      if (plainText[i] != '\u00AD') continue;
      if (i == 0 || i + 1 >= plainText.length) continue;

      // Get the rendered boxes for the character BEFORE and AFTER
      // the soft hyphen. If they're on different lines (different y),
      // the soft hyphen caused a line break.
      final beforeBoxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: i - 1, extentOffset: i),
      );
      final afterBoxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: i + 1, extentOffset: i + 2),
      );

      if (beforeBoxes.isNotEmpty && afterBoxes.isNotEmpty) {
        // Compare vertical positions — different line = different top.
        final beforeBottom = beforeBoxes.last.bottom;
        final afterTop = afterBoxes.first.top;
        if (afterTop >= beforeBottom - 1) {
          // The character after the soft hyphen starts at or below
          // where the character before it ends — they're on different lines.
          softHyphenBreaks.add(i);
        }
      }
    }

    painter.dispose();

    _lastBreakPositions = softHyphenBreaks;

    // Replace soft hyphens: '-' at break positions, strip elsewhere.
    // Stripping non-break soft hyphens prevents Flutter from re-breaking
    // at different positions than we calculated.
    return _replaceInSpan(widget.textSpan, softHyphenBreaks, 0).span;
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

      // Check if any soft hyphens exist in this text segment.
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
              buf.write('-'); // visible hyphen at line break
            }
            // non-break soft hyphens are stripped (not written)
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
