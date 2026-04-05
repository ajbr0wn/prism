import 'package:flutter/material.dart';

/// Fixes Flutter's soft hyphen rendering bug (flutter/flutter#18443).
///
/// Flutter's text engine breaks lines at soft hyphens (\u00AD) but never
/// renders the visible hyphen glyph. This widget detects which soft hyphens
/// land at line breaks and replaces them with visible hyphens.
///
/// Implementation: first renders the unmodified text, then measures its
/// actual width via the render tree in a post-frame callback, and rebuilds
/// with visible hyphens at line break positions. Avoids LayoutBuilder
/// because wrapping SelectableText.rich in LayoutBuilder causes paragraph
/// rendering to collapse into empty grey rectangles.
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
  State<SoftHyphenText> createState() => _SoftHyphenTextState();
}

class _SoftHyphenTextState extends State<SoftHyphenText> {
  final _measureKey = GlobalKey();
  TextSpan? _processedSpan;
  double? _lastWidth;

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

    // Match SelectableText's layout parameters as closely as possible,
    // especially textScaler — mismatched scaling causes different line
    // break positions and makes our detection miss hyphens.
    final painter = TextPainter(
      text: widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    );
    painter.layout(maxWidth: maxWidth);

    final breakPositions = <int>{};
    // Walk each soft hyphen and check if it sits at a line break.
    // Previous approach used getPositionForOffset at line edges, but
    // soft hyphens are zero-width so the pixel-based hit test misses them.
    // Instead, use getLineBoundary: if the character after a soft hyphen
    // starts a new line, that soft hyphen caused the break.
    for (var i = 0; i < plainText.length; i++) {
      if (plainText[i] != '\u00AD') continue;
      if (i + 1 >= plainText.length) continue;

      // Where does the soft hyphen sit vs the next character?
      final shyLine = painter.getLineBoundary(TextPosition(offset: i));
      final nextLine =
          painter.getLineBoundary(TextPosition(offset: i + 1));

      // If the soft hyphen and the next character are on different lines,
      // this soft hyphen is the line break point — show a visible hyphen.
      if (shyLine.start != nextLine.start) {
        breakPositions.add(i);
      }
    }

    painter.dispose();

    if (breakPositions.isEmpty) return widget.textSpan;

    return _replaceInSpan(widget.textSpan, breakPositions, 0).span;
  }

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

      bool needsChange = false;
      for (var i = 0; i < text.length; i++) {
        if (text[i] == '\u00AD' && breakPositions.contains(offset + i)) {
          needsChange = true;
          break;
        }
      }

      if (needsChange) {
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
