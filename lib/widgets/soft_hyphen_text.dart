import 'package:flutter/material.dart';

/// Fixes Flutter's soft hyphen rendering bug (flutter/flutter#18443).
///
/// Flutter's text engine breaks lines at soft hyphens (\u00AD) but never
/// renders the visible hyphen glyph. This widget detects which soft hyphens
/// land at line breaks and replaces them with visible hyphens.
class SoftHyphenText extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final processed = _fixSoftHyphens(constraints.maxWidth);
        return SelectableText.rich(
          processed,
          textAlign: textAlign,
          contextMenuBuilder: contextMenuBuilder,
        );
      },
    );
  }

  TextSpan _fixSoftHyphens(double maxWidth) {
    final plainText = textSpan.toPlainText();
    if (!plainText.contains('\u00AD')) return textSpan;

    // Layout to find where lines break
    final painter = TextPainter(
      text: textSpan,
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: maxWidth);

    // Find soft hyphens that sit at line break positions
    final breakPositions = <int>{};
    for (var i = 0; i < plainText.length; i++) {
      if (plainText[i] != '\u00AD') continue;
      final boundary = painter.getLineBoundary(TextPosition(offset: i));
      // The soft hyphen is the last character on this line
      if (boundary.end == i + 1) {
        breakPositions.add(i);
      }
    }

    painter.dispose();

    if (breakPositions.isEmpty) return textSpan;

    // Walk the span tree and replace those soft hyphens with visible hyphens
    return _replaceInSpan(textSpan, breakPositions, 0).span;
  }

  static ({TextSpan span, int offset}) _replaceInSpan(
    TextSpan span,
    Set<int> breakPositions,
    int offset,
  ) {
    // Process this span's direct text
    String? processedText;
    var textEnd = offset;
    if (span.text != null) {
      final text = span.text!;
      textEnd = offset + text.length;

      // Check if any soft hyphens in this text segment need replacing
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

    // Process children
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
          // WidgetSpan counts as 1 character in toPlainText()
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
