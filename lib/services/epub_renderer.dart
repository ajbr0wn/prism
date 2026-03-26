import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../models/highlight.dart';
import '../models/reading_settings.dart';
import '../models/reading_theme.dart';
import 'hyphenation.dart';

/// Converts EPUB XHTML content into styled Flutter widgets.
/// Supports highlighting, configurable reading settings, and Kindle-style formatting.
class EpubRenderer {
  final ReadingTheme theme;
  final ReadingSettings settings;
  final List<Highlight> chapterHighlights;
  final void Function(int paragraphIndex, int start, int end, String text)?
      onHighlight;

  int _paragraphCounter = 0;

  EpubRenderer({
    required this.theme,
    required this.settings,
    this.chapterHighlights = const [],
    this.onHighlight,
  });

  TextStyle get _baseStyle => settings.fontTextStyle.copyWith(
        color: theme.textColor,
        fontSize: settings.fontSize,
        height: settings.lineHeight,
        letterSpacing: 0.1,
      );

  /// Render an XHTML string into a list of widgets.
  List<Widget> render(String xhtml) {
    _paragraphCounter = 0;
    try {
      final doc = XmlDocument.parse(xhtml);
      final body = doc.findAllElements('body').firstOrNull;
      if (body == null) return [_text('Could not parse chapter content.')];
      return _renderBlockChildren(body);
    } catch (e) {
      return [_text('Error rendering content: $e')];
    }
  }

  List<Widget> _renderBlockChildren(XmlElement element) {
    final widgets = <Widget>[];

    for (final child in element.children) {
      if (child is XmlElement) {
        final tag = child.localName.toLowerCase();
        switch (tag) {
          case 'h1':
            widgets.add(_renderHeading(child, 1));
          case 'h2':
            widgets.add(_renderHeading(child, 2));
          case 'h3':
            widgets.add(_renderHeading(child, 3));
          case 'h4':
            widgets.add(_renderHeading(child, 4));
          case 'h5' || 'h6':
            widgets.add(_renderHeading(child, 5));
          case 'p':
            final w = _renderParagraph(child);
            if (w != null) widgets.add(w);
          case 'div' || 'section' || 'article' || 'aside' || 'nav' ||
               'header' || 'footer' || 'main':
            widgets.addAll(_renderBlockChildren(child));
          case 'blockquote':
            widgets.add(_renderBlockquote(child));
          case 'ul' || 'ol':
            widgets.add(_renderList(child, ordered: tag == 'ol'));
          case 'hr':
            widgets.add(_renderHr());
          case 'br':
            widgets.add(SizedBox(height: settings.fontSize * 0.5));
          case 'img' || 'image' || 'svg':
            break;
          case 'table' || 'tbody' || 'thead':
            widgets.addAll(_renderBlockChildren(child));
          case 'tr':
            final spans = _renderInlineChildren(child);
            if (spans.isNotEmpty) {
              widgets.add(_buildParagraphWidget(spans));
            }
          case 'head' || 'style' || 'script' || 'link' || 'meta' || 'title':
            break;
          default:
            final spans = _renderInlineChildren(child);
            if (spans.isNotEmpty) {
              widgets.add(_buildParagraphWidget(spans));
            }
        }
      } else if (child is XmlText) {
        final text = child.value.trim();
        if (text.isNotEmpty) {
          widgets.add(_buildParagraphWidget([TextSpan(text: text)]));
        }
      }
    }

    return widgets;
  }

  Widget _renderHeading(XmlElement element, int level) {
    final double size;
    final FontWeight weight;
    switch (level) {
      case 1:
        size = settings.fontSize * 1.6;
        weight = FontWeight.w700;
      case 2:
        size = settings.fontSize * 1.4;
        weight = FontWeight.w600;
      case 3:
        size = settings.fontSize * 1.2;
        weight = FontWeight.w600;
      case 4:
        size = settings.fontSize * 1.1;
        weight = FontWeight.w600;
      default:
        size = settings.fontSize * 1.05;
        weight = FontWeight.w500;
    }

    return Padding(
      padding: EdgeInsets.only(
        top: settings.fontSize * (level <= 2 ? 1.5 : 1.0),
        bottom: settings.fontSize * 0.5,
      ),
      child: SelectableText.rich(
        TextSpan(
          style: settings.fontTextStyle.copyWith(
            color: theme.headingColor,
            fontSize: size,
            fontWeight: weight,
            height: 1.3,
            letterSpacing: level <= 2 ? 0.3 : 0.2,
          ),
          children: _renderInlineChildren(element),
        ),
        textAlign: settings.textAlign,
      ),
    );
  }

  Widget? _renderParagraph(XmlElement element) {
    final spans = _renderInlineChildren(element);
    if (spans.isEmpty) return null;

    final hasContent = spans.any((span) {
      if (span is TextSpan) {
        return (span.text != null && span.text!.trim().isNotEmpty) ||
            (span.children != null && span.children!.isNotEmpty);
      }
      return true;
    });
    if (!hasContent) return null;

    return _buildParagraphWidget(spans);
  }

  Widget _buildParagraphWidget(List<InlineSpan> spans) {
    final pIdx = _paragraphCounter++;

    // Add first-line indent (book-style paragraph separation)
    if (settings.paragraphIndent && pIdx > 0) {
      spans = [
        TextSpan(text: '\u2003\u2003'), // two em-spaces for indent
        ...spans,
      ];
    }

    // Get highlights for this paragraph
    final pHighlights =
        chapterHighlights.where((h) => h.paragraphIndex == pIdx).toList();

    // Apply highlight background colors if any
    List<InlineSpan> styledSpans;
    if (pHighlights.isNotEmpty) {
      final plainText = _flattenSpans(spans);
      final charColors = List<Color?>.filled(plainText.length, null);
      for (final h in pHighlights) {
        final color = Highlight.colors[h.colorIndex];
        for (var i = h.startOffset;
            i < h.endOffset && i < plainText.length;
            i++) {
          charColors[i] = color;
        }
      }
      styledSpans = _HighlightApplier(charColors).process(spans);
    } else {
      styledSpans = spans;
    }

    final textSpan = TextSpan(style: _baseStyle, children: styledSpans);

    // Use tighter spacing when paragraph indent is active (book-style)
    final bottomPadding = settings.paragraphIndent
        ? settings.fontSize * 0.15
        : settings.fontSize * 0.7;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SelectableText.rich(
        textSpan,
        textAlign: settings.textAlign,
        contextMenuBuilder: onHighlight != null
            ? (context, editableTextState) =>
                _buildContextMenu(context, editableTextState, pIdx)
            : null,
      ),
    );
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
    int paragraphIndex,
  ) {
    final selection = editableTextState.textEditingValue.selection;
    final fullText = editableTextState.textEditingValue.text;

    final buttonItems = List<ContextMenuButtonItem>.of(
        editableTextState.contextMenuButtonItems);

    if (selection.isValid && !selection.isCollapsed && onHighlight != null) {
      for (var i = 0; i < Highlight.colors.length; i++) {
        buttonItems.add(ContextMenuButtonItem(
          label: 'Highlight ${Highlight.colorNames[i]}',
          onPressed: () {
            final selectedText =
                fullText.substring(selection.start, selection.end);
            onHighlight!(
                paragraphIndex, selection.start, selection.end, selectedText);
            editableTextState.hideToolbar();
          },
        ));
      }
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  Widget _renderBlockquote(XmlElement element) {
    return Padding(
      padding: EdgeInsets.only(
        left: settings.fontSize * 1.2,
        bottom: settings.fontSize * 0.5,
        top: settings.fontSize * 0.3,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.accentColor.withValues(alpha: 0.4),
              width: 3,
            ),
          ),
        ),
        padding: EdgeInsets.only(left: settings.fontSize * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _renderBlockChildren(element),
        ),
      ),
    );
  }

  Widget _renderList(XmlElement element, {required bool ordered}) {
    final items = element.findAllElements('li').toList();

    return Padding(
      padding: EdgeInsets.only(
        left: settings.fontSize * 1.0,
        bottom: settings.fontSize * 0.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: settings.fontSize * 0.25),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: settings.fontSize * 1.5,
                    child: Text(
                      ordered ? '${i + 1}.' : '\u2022',
                      style: TextStyle(
                        color: theme.accentColor,
                        fontSize: settings.fontSize,
                        height: settings.lineHeight,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText.rich(
                      TextSpan(
                        style: _baseStyle,
                        children: _renderInlineChildren(items[i]),
                      ),
                      textAlign: settings.textAlign,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _renderHr() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: settings.fontSize * 1.2),
      child: Center(
        child: Text(
          '* * *',
          style: TextStyle(
            color: theme.accentColor.withValues(alpha: 0.4),
            fontSize: settings.fontSize,
            letterSpacing: 8,
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _renderInlineChildren(XmlElement element) {
    final spans = <InlineSpan>[];

    for (final child in element.children) {
      if (child is XmlText) {
        var text = child.value.replaceAll(RegExp(r'\s+'), ' ');
        if (text.isNotEmpty) {
          // Insert soft hyphens for better justified text layout
          if (settings.textAlign == TextAlign.justify) {
            text = Hyphenation.instance.process(text);
          }
          spans.add(TextSpan(text: text));
        }
      } else if (child is XmlElement) {
        final tag = child.localName.toLowerCase();
        switch (tag) {
          case 'em' || 'i' || 'cite':
            spans.add(TextSpan(
              style: const TextStyle(fontStyle: FontStyle.italic),
              children: _renderInlineChildren(child),
            ));
          case 'strong' || 'b':
            spans.add(TextSpan(
              style: const TextStyle(fontWeight: FontWeight.bold),
              children: _renderInlineChildren(child),
            ));
          case 'sup':
            // Superscript: smaller text for footnote references
            spans.add(TextSpan(
              style: TextStyle(
                fontSize: settings.fontSize * 0.65,
                color: theme.linkColor,
              ),
              children: _renderInlineChildren(child),
            ));
          case 'sub':
            spans.add(TextSpan(
              style: TextStyle(fontSize: settings.fontSize * 0.65),
              children: _renderInlineChildren(child),
            ));
          case 'a':
            // Check if this is a footnote link (short text, likely a number)
            final linkText = _getPlainText(child).trim();
            final isFootnote =
                linkText.length <= 4 && RegExp(r'^\d+$').hasMatch(linkText);

            if (isFootnote) {
              // Render as superscript footnote reference
              spans.add(TextSpan(
                style: TextStyle(
                  color: theme.linkColor,
                  fontSize: settings.fontSize * 0.65,
                ),
                children: _renderInlineChildren(child),
              ));
            } else {
              spans.add(TextSpan(
                style: TextStyle(
                  color: theme.linkColor,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.linkColor.withValues(alpha: 0.4),
                ),
                children: _renderInlineChildren(child),
              ));
            }
          case 'br':
            spans.add(const TextSpan(text: '\n'));
          case 'span' || 'small' || 'abbr' || 'code' || 'tt' || 'u' ||
               'td' || 'th':
            spans.addAll(_renderInlineChildren(child));
          case 'img' || 'image' || 'svg':
            break;
          default:
            spans.addAll(_renderInlineChildren(child));
        }
      }
    }

    return spans;
  }

  String _getPlainText(XmlElement element) {
    final buffer = StringBuffer();
    for (final child in element.children) {
      if (child is XmlText) {
        buffer.write(child.value);
      } else if (child is XmlElement) {
        buffer.write(_getPlainText(child));
      }
    }
    return buffer.toString();
  }

  String _flattenSpans(List<InlineSpan> spans) {
    final buffer = StringBuffer();
    for (final span in spans) {
      if (span is TextSpan) {
        if (span.text != null) buffer.write(span.text);
        if (span.children != null) {
          buffer.write(_flattenSpans(span.children!.cast<InlineSpan>()));
        }
      }
    }
    return buffer.toString();
  }

  Widget _text(String text) {
    return Text(text, style: TextStyle(color: theme.textColor));
  }
}

/// Walks a span tree and applies highlight background colors at the
/// correct character offsets.
class _HighlightApplier {
  final List<Color?> charColors;
  int _offset = 0;

  _HighlightApplier(this.charColors);

  List<InlineSpan> process(List<InlineSpan> spans) {
    _offset = 0;
    return _processSpans(spans);
  }

  List<InlineSpan> _processSpans(List<InlineSpan> spans) {
    final result = <InlineSpan>[];
    for (final span in spans) {
      if (span is TextSpan) {
        result.addAll(_processTextSpan(span));
      } else {
        result.add(span);
      }
    }
    return result;
  }

  List<InlineSpan> _processTextSpan(TextSpan span) {
    if (span.text != null && span.text!.isNotEmpty) {
      if (span.children == null || span.children!.isEmpty) {
        return _splitText(span.text!, span.style);
      } else {
        final textParts = _splitText(span.text!, span.style);
        final childParts =
            _processSpans(span.children!.cast<InlineSpan>());
        return [...textParts, ...childParts];
      }
    }

    if (span.children != null && span.children!.isNotEmpty) {
      final processed =
          _processSpans(span.children!.cast<InlineSpan>());
      return [TextSpan(style: span.style, children: processed)];
    }

    return [span];
  }

  List<InlineSpan> _splitText(String text, TextStyle? baseStyle) {
    final spans = <InlineSpan>[];
    var i = 0;
    while (i < text.length) {
      final charIdx = _offset + i;
      final color =
          charIdx < charColors.length ? charColors[charIdx] : null;

      var j = i + 1;
      while (j < text.length) {
        final nextIdx = _offset + j;
        final nextColor =
            nextIdx < charColors.length ? charColors[nextIdx] : null;
        if (nextColor != color) break;
        j++;
      }

      final runText = text.substring(i, j);
      final style = color != null
          ? (baseStyle ?? const TextStyle()).copyWith(backgroundColor: color)
          : baseStyle;

      spans.add(TextSpan(text: runText, style: style));
      i = j;
    }
    _offset += text.length;
    return spans;
  }
}
