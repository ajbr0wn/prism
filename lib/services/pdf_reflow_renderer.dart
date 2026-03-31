import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../models/reading_settings.dart';
import '../models/reading_theme.dart';
import 'pdf_text_extractor.dart';

/// Renders extracted PDF content blocks as themed Flutter widgets,
/// with support for math equations, figures, and academic formatting.
class PdfReflowRenderer {
  final ReadingTheme theme;
  final ReadingSettings settings;

  const PdfReflowRenderer({
    required this.theme,
    required this.settings,
  });

  TextStyle get _baseStyle => settings.applyFont(TextStyle(
        color: theme.textColor,
        fontSize: settings.fontSize,
        height: settings.lineHeight,
        letterSpacing: 0.1,
      ));

  /// Render a list of content blocks into widgets.
  List<Widget> render(List<PdfContentBlock> blocks) {
    final widgets = <Widget>[];

    for (final block in blocks) {
      switch (block.type) {
        case PdfBlockType.heading:
          widgets.add(_renderHeading(block));
        case PdfBlockType.paragraph:
          widgets.add(_renderParagraph(block));
        case PdfBlockType.equation:
          widgets.add(_renderEquation(block));
        case PdfBlockType.figure:
          widgets.add(_renderFigure(block));
        case PdfBlockType.caption:
          widgets.add(_renderCaption(block));
        case PdfBlockType.listItem:
          widgets.add(_renderListItem(block));
        case PdfBlockType.table:
          widgets.add(_renderParagraph(block)); // Fallback
      }
    }

    return widgets;
  }

  /// Render all pages' content blocks with page separators.
  List<Widget> renderDocument(List<List<PdfContentBlock>> pages) {
    final widgets = <Widget>[];

    for (var i = 0; i < pages.length; i++) {
      widgets.addAll(render(pages[i]));

      // Page separator
      if (i < pages.length - 1) {
        widgets.add(Padding(
          padding: EdgeInsets.symmetric(vertical: settings.fontSize * 1.5),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 0.5,
                  color: theme.accentColor.withValues(alpha: 0.1),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: settings.fontSize),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.2),
                    fontSize: settings.fontSize * 0.7,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 0.5,
                  color: theme.accentColor.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ));
      }
    }

    return widgets;
  }

  Widget _renderHeading(PdfContentBlock block) {
    final double size;
    final FontWeight weight;
    switch (block.headingLevel) {
      case 1:
        size = settings.fontSize * 2.0;
        weight = FontWeight.w800;
      case 2:
        size = settings.fontSize * 1.6;
        weight = FontWeight.w700;
      default:
        size = settings.fontSize * 1.35;
        weight = FontWeight.w600;
    }

    final heading = SelectableText(
      block.text,
      style: settings.applyFont(TextStyle(
        color: theme.headingColor,
        fontSize: size,
        fontWeight: weight,
        height: 1.25,
        letterSpacing: block.headingLevel <= 2 ? 0.4 : 0.2,
      )),
      textAlign: block.headingLevel == 1 ? TextAlign.center : settings.textAlign,
    );

    if (block.headingLevel == 1) {
      return Padding(
        padding: EdgeInsets.only(
          top: settings.fontSize * 2.5,
          bottom: settings.fontSize * 1.0,
        ),
        child: Column(
          children: [
            heading,
            SizedBox(height: settings.fontSize * 0.6),
            Container(
              width: settings.fontSize * 3,
              height: 1.5,
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: settings.fontSize * (block.headingLevel == 2 ? 2.0 : 1.2),
        bottom: settings.fontSize * 0.5,
      ),
      child: heading,
    );
  }

  Widget _renderParagraph(PdfContentBlock block) {
    // Check for inline math and render mixed content
    final text = block.text;
    if (_containsInlineMath(text)) {
      return Padding(
        padding: EdgeInsets.only(bottom: settings.fontSize * 0.7),
        child: _buildMixedContent(text),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: settings.fontSize * 0.7),
      child: SelectableText(
        text,
        style: _baseStyle,
        textAlign: settings.textAlign,
      ),
    );
  }

  Widget _renderEquation(PdfContentBlock block) {
    final tex = textToTex(block.text);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: settings.fontSize * 0.8),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: settings.fontSize * 1.0,
            vertical: settings.fontSize * 0.5,
          ),
          decoration: BoxDecoration(
            color: theme.backgroundColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Math.tex(
            tex,
            mathStyle: MathStyle.display,
            textStyle: TextStyle(
              color: theme.textColor,
              fontSize: settings.fontSize * 1.1,
            ),
            onErrorFallback: (error) => SelectableText(
              block.text,
              style: TextStyle(
                color: theme.textColor,
                fontSize: settings.fontSize,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _renderFigure(PdfContentBlock block) {
    if (block.imageBytes == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: settings.fontSize * 1.0),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(
            Uint8List.fromList(block.imageBytes!),
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        ),
      ),
    );
  }

  Widget _renderCaption(PdfContentBlock block) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: settings.fontSize * 0.8,
        left: settings.fontSize * 1.0,
        right: settings.fontSize * 1.0,
      ),
      child: SelectableText(
        block.text,
        style: settings.applyFont(TextStyle(
          color: theme.textColor.withValues(alpha: 0.7),
          fontSize: settings.fontSize * 0.85,
          fontStyle: FontStyle.italic,
          height: settings.lineHeight,
        )),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _renderListItem(PdfContentBlock block) {
    // Extract bullet/number and content
    final match = RegExp(r'^([•\-–—]|\d+[.)]|[a-z][.)]|[ivxIVX]+[.)])\s*(.*)$')
        .firstMatch(block.text);
    final marker = match?.group(1) ?? '\u2022';
    final content = match?.group(2) ?? block.text;

    return Padding(
      padding: EdgeInsets.only(
        left: settings.fontSize * 1.0,
        bottom: settings.fontSize * 0.25,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: settings.fontSize * 1.5,
            child: Text(
              marker,
              style: TextStyle(
                color: theme.accentColor,
                fontSize: settings.fontSize,
                height: settings.lineHeight,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              content,
              style: _baseStyle,
              textAlign: settings.textAlign,
            ),
          ),
        ],
      ),
    );
  }

  // ── Inline math handling ──

  /// Check if text contains inline math delimiters.
  bool _containsInlineMath(String text) {
    return text.contains(r'$') ||
        text.contains(r'\(') ||
        text.contains(r'\)');
  }

  /// Build a widget with mixed text and inline math.
  Widget _buildMixedContent(String text) {
    final parts = _splitInlineMath(text);

    if (parts.length == 1 && !parts[0].isMath) {
      return SelectableText(text, style: _baseStyle, textAlign: settings.textAlign);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts.map((part) {
        if (part.isMath) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Math.tex(
              textToTex(part.text),
              mathStyle: MathStyle.text,
              textStyle: TextStyle(
                color: theme.textColor,
                fontSize: settings.fontSize,
              ),
              onErrorFallback: (error) => Text(
                part.text,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: settings.fontSize,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          );
        } else {
          return Text(part.text, style: _baseStyle);
        }
      }).toList(),
    );
  }

  /// Split text into alternating text/math segments.
  List<_MathSegment> _splitInlineMath(String text) {
    final segments = <_MathSegment>[];
    final pattern = RegExp(r'\$([^$]+)\$|\\\((.+?)\\\)');
    var lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        segments.add(_MathSegment(text.substring(lastEnd, match.start), false));
      }
      final mathContent = match.group(1) ?? match.group(2) ?? '';
      segments.add(_MathSegment(mathContent, true));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      segments.add(_MathSegment(text.substring(lastEnd), false));
    }

    if (segments.isEmpty) {
      segments.add(_MathSegment(text, false));
    }

    return segments;
  }

  /// Convert extracted text to something flutter_math_fork can render.
  /// This handles common Unicode math symbols → LaTeX conversion.
  static String textToTex(String text) {
    var tex = text.trim();

    // Unicode math symbols → LaTeX
    tex = tex
        .replaceAll('α', r'\alpha')
        .replaceAll('β', r'\beta')
        .replaceAll('γ', r'\gamma')
        .replaceAll('δ', r'\delta')
        .replaceAll('ε', r'\epsilon')
        .replaceAll('ζ', r'\zeta')
        .replaceAll('η', r'\eta')
        .replaceAll('θ', r'\theta')
        .replaceAll('λ', r'\lambda')
        .replaceAll('μ', r'\mu')
        .replaceAll('ξ', r'\xi')
        .replaceAll('π', r'\pi')
        .replaceAll('ρ', r'\rho')
        .replaceAll('σ', r'\sigma')
        .replaceAll('τ', r'\tau')
        .replaceAll('φ', r'\phi')
        .replaceAll('ψ', r'\psi')
        .replaceAll('ω', r'\omega')
        .replaceAll('Γ', r'\Gamma')
        .replaceAll('Δ', r'\Delta')
        .replaceAll('Θ', r'\Theta')
        .replaceAll('Λ', r'\Lambda')
        .replaceAll('Σ', r'\Sigma')
        .replaceAll('Φ', r'\Phi')
        .replaceAll('Ψ', r'\Psi')
        .replaceAll('Ω', r'\Omega')
        .replaceAll('∞', r'\infty')
        .replaceAll('∂', r'\partial')
        .replaceAll('∇', r'\nabla')
        .replaceAll('∫', r'\int')
        .replaceAll('∑', r'\sum')
        .replaceAll('∏', r'\prod')
        .replaceAll('√', r'\sqrt')
        .replaceAll('≈', r'\approx')
        .replaceAll('≠', r'\neq')
        .replaceAll('≤', r'\leq')
        .replaceAll('≥', r'\geq')
        .replaceAll('±', r'\pm')
        .replaceAll('×', r'\times')
        .replaceAll('÷', r'\div')
        .replaceAll('∈', r'\in')
        .replaceAll('∉', r'\notin')
        .replaceAll('⊂', r'\subset')
        .replaceAll('⊃', r'\supset')
        .replaceAll('∪', r'\cup')
        .replaceAll('∩', r'\cap')
        .replaceAll('∀', r'\forall')
        .replaceAll('∃', r'\exists')
        .replaceAll('→', r'\rightarrow')
        .replaceAll('←', r'\leftarrow')
        .replaceAll('⇒', r'\Rightarrow')
        .replaceAll('⇐', r'\Leftarrow')
        .replaceAll('·', r'\cdot');

    // Remove LaTeX delimiters if present
    tex = tex
        .replaceAll(RegExp(r'^\\\['), '')
        .replaceAll(RegExp(r'\\\]$'), '')
        .replaceAll(RegExp(r'^\$\$'), '')
        .replaceAll(RegExp(r'\$\$$'), '')
        .replaceAll(RegExp(r'^\$'), '')
        .replaceAll(RegExp(r'\$$'), '')
        .trim();

    return tex;
  }
}

class _MathSegment {
  final String text;
  final bool isMath;
  const _MathSegment(this.text, this.isMath);
}
