import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../models/reading_theme.dart';

/// Converts EPUB XHTML content into styled Flutter widgets.
class EpubRenderer {
  final ReadingTheme theme;

  const EpubRenderer({required this.theme});

  /// Render an XHTML string into a list of widgets.
  List<Widget> render(String xhtml) {
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
            widgets.add(_renderParagraph(child));
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
            widgets.add(const SizedBox(height: 8));
          case 'img' || 'image':
            // Skip images for now - could add later
            break;
          case 'table':
            // Simplified table rendering
            widgets.addAll(_renderBlockChildren(child));
          case 'tr':
            final spans = _renderInlineChildren(child);
            if (spans.isNotEmpty) {
              widgets.add(_buildParagraphWidget(spans));
            }
          case 'head' || 'style' || 'script' || 'link' || 'meta':
            break; // Skip non-content elements
          default:
            // Try to render as a paragraph if it has text content
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
    switch (level) {
      case 1:
        size = theme.fontSize * 1.8;
      case 2:
        size = theme.fontSize * 1.5;
      case 3:
        size = theme.fontSize * 1.3;
      case 4:
        size = theme.fontSize * 1.15;
      default:
        size = theme.fontSize * 1.05;
    }

    return Padding(
      padding: EdgeInsets.only(
        top: theme.fontSize * (level <= 2 ? 1.5 : 1.0),
        bottom: theme.fontSize * 0.5,
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: theme.headingColor,
            fontSize: size,
            fontWeight: FontWeight.bold,
            height: 1.3,
            fontFamily: theme.fontFamily,
          ),
          children: _renderInlineChildren(element),
        ),
      ),
    );
  }

  Widget _renderParagraph(XmlElement element) {
    final spans = _renderInlineChildren(element);
    if (spans.isEmpty) return const SizedBox.shrink();
    return _buildParagraphWidget(spans);
  }

  Widget _buildParagraphWidget(List<InlineSpan> spans) {
    return Padding(
      padding: EdgeInsets.only(bottom: theme.fontSize * 0.6),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: theme.textColor,
            fontSize: theme.fontSize,
            height: theme.lineHeight,
            fontFamily: theme.fontFamily,
          ),
          children: spans,
        ),
      ),
    );
  }

  Widget _renderBlockquote(XmlElement element) {
    return Padding(
      padding: EdgeInsets.only(
        left: theme.fontSize * 1.5,
        bottom: theme.fontSize * 0.6,
        top: theme.fontSize * 0.3,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.accentColor.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
        ),
        padding: EdgeInsets.only(left: theme.fontSize * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _renderBlockChildren(element),
        ),
      ),
    );
  }

  Widget _renderList(XmlElement element, {required bool ordered}) {
    final items = element
        .findAllElements('li')
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: theme.fontSize * 1.2,
        bottom: theme.fontSize * 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: theme.fontSize * 0.25),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: theme.fontSize * 1.5,
                    child: Text(
                      ordered ? '${i + 1}.' : '\u2022',
                      style: TextStyle(
                        color: theme.accentColor,
                        fontSize: theme.fontSize,
                        height: theme.lineHeight,
                      ),
                    ),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: theme.fontSize,
                          height: theme.lineHeight,
                          fontFamily: theme.fontFamily,
                        ),
                        children: _renderInlineChildren(items[i]),
                      ),
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
      padding: EdgeInsets.symmetric(vertical: theme.fontSize),
      child: Divider(
        color: theme.accentColor.withValues(alpha: 0.3),
        thickness: 1,
      ),
    );
  }

  List<InlineSpan> _renderInlineChildren(XmlElement element) {
    final spans = <InlineSpan>[];

    for (final child in element.children) {
      if (child is XmlText) {
        final text = child.value.replaceAll(RegExp(r'\s+'), ' ');
        if (text.isNotEmpty) {
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
          case 'a':
            spans.add(TextSpan(
              style: TextStyle(
                color: theme.linkColor,
                decoration: TextDecoration.underline,
                decorationColor: theme.linkColor.withValues(alpha: 0.5),
              ),
              children: _renderInlineChildren(child),
            ));
          case 'br':
            spans.add(const TextSpan(text: '\n'));
          case 'span' || 'small' || 'sub' || 'sup' || 'abbr' || 'code' ||
               'tt' || 'u':
            spans.addAll(_renderInlineChildren(child));
          case 'img' || 'image':
            break; // Skip inline images for now
          default:
            spans.addAll(_renderInlineChildren(child));
        }
      }
    }

    return spans;
  }

  Widget _text(String text) {
    return Text(text, style: TextStyle(color: theme.textColor));
  }
}
