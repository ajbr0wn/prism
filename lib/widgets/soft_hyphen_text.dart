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

    // Layout as a SINGLE LINE to get reliable x-coordinates for each
    // character position. Single-line measurement works on all platforms;
    // the bug only affects multi-line boundary detection APIs.
    final painter = TextPainter(
      text: widget.textSpan,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    );
    painter.layout(maxWidth: double.infinity);

    // Measure the width of a visible hyphen in the base style.
    final hyphenPainter = TextPainter(
      text: TextSpan(text: '-', style: widget.textSpan.style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    );
    hyphenPainter.layout();
    final hyphenWidth = hyphenPainter.size.width;
    hyphenPainter.dispose();

    // x-coordinate at a character offset in the single-line layout.
    double xAt(int offset) {
      if (offset <= 0) return 0;
      if (offset >= plainText.length) return painter.size.width;
      return painter
          .getOffsetForCaret(TextPosition(offset: offset), Rect.zero)
          .dx;
    }

    // Collect all break opportunities (spaces and soft hyphens).
    final breakOpps = <int>[];
    for (var i = 0; i < plainText.length; i++) {
      if (plainText[i] == ' ' || plainText[i] == '\u00AD') {
        breakOpps.add(i);
      }
    }

    // Compute our own line breaks using character widths from the
    // single-line layout. For each line, binary search for the last
    // break opportunity where text from lineStart fits within maxWidth.
    final softHyphenBreaks = <int>{};
    var lineStart = 0;
    var lineStartX = 0.0;

    while (lineStart < plainText.length) {
      // Does the remaining text fit on this line?
      if (xAt(plainText.length) - lineStartX <= maxWidth) break;

      // Break opportunities after lineStart.
      final opps = breakOpps.where((b) => b > lineStart).toList();
      if (opps.isEmpty) break;

      // Binary search: last break opp that fits.
      var bestIdx = -1;
      var lo = 0, hi = opps.length - 1;
      while (lo <= hi) {
        final mid = (lo + hi) ~/ 2;
        final opp = opps[mid];
        final double width;
        if (plainText[opp] == '\u00AD') {
          // Soft hyphen: text before it + visible hyphen.
          width = (xAt(opp) - lineStartX) + hyphenWidth;
        } else {
          // Space: text before it (trailing space is trimmed).
          width = xAt(opp) - lineStartX;
        }

        if (width <= maxWidth) {
          bestIdx = mid;
          lo = mid + 1;
        } else {
          hi = mid - 1;
        }
      }

      if (bestIdx == -1) break; // first word exceeds line width

      final breakAt = opps[bestIdx];
      if (plainText[breakAt] == '\u00AD') {
        softHyphenBreaks.add(breakAt);
      }

      lineStart = breakAt + 1;
      lineStartX = xAt(lineStart);
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
