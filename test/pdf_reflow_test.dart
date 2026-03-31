import 'package:flutter_test/flutter_test.dart';
import 'package:prism/services/pdf_text_extractor.dart';
import 'package:prism/services/pdf_reflow_renderer.dart';

void main() {
  group('PdfTextExtractor content detection', () {
    test('detects equations with LaTeX delimiters', () {
      expect(PdfTextExtractor.looksLikeEquation(r'\begin{equation} x^2 \end{equation}'), isTrue);
      expect(PdfTextExtractor.looksLikeEquation(r'$$ \frac{a}{b} $$'), isTrue);
      expect(PdfTextExtractor.looksLikeEquation(r'\[ x + y = z \]'), isTrue);
    });

    test('detects equations with high math symbol density', () {
      expect(PdfTextExtractor.looksLikeEquation('α + β = γ × δ ÷ ε'), isTrue);
      expect(PdfTextExtractor.looksLikeEquation('∫∑∏ f(x)'), isTrue);
    });

    test('does not flag regular text as equations', () {
      expect(PdfTextExtractor.looksLikeEquation('This is a normal sentence.'), isFalse);
      expect(PdfTextExtractor.looksLikeEquation('The results are shown in Table 2.'), isFalse);
    });

    test('detects list items with various markers', () {
      expect(PdfTextExtractor.looksLikeListItem('• First item'), isTrue);
      expect(PdfTextExtractor.looksLikeListItem('- Second item'), isTrue);
      expect(PdfTextExtractor.looksLikeListItem('– Dash item'), isTrue);
      expect(PdfTextExtractor.looksLikeListItem('1. Numbered'), isTrue);
      expect(PdfTextExtractor.looksLikeListItem('1) Numbered paren'), isTrue);
      expect(PdfTextExtractor.looksLikeListItem('a) Lettered'), isTrue);
      expect(PdfTextExtractor.looksLikeListItem('iv. Roman numeral'), isTrue);
    });

    test('does not flag regular text as list items', () {
      expect(PdfTextExtractor.looksLikeListItem('Regular text'), isFalse);
      expect(PdfTextExtractor.looksLikeListItem('A sentence starting with A.'), isFalse);
    });

    test('detects figure and table captions', () {
      expect(PdfTextExtractor.looksLikeCaption('Figure 1: A diagram'), isTrue);
      expect(PdfTextExtractor.looksLikeCaption('Fig. 3 Results overview'), isTrue);
      expect(PdfTextExtractor.looksLikeCaption('Table 2: Performance comparison'), isTrue);
      expect(PdfTextExtractor.looksLikeCaption('Algorithm 1 The main loop'), isTrue);
      expect(PdfTextExtractor.looksLikeCaption('Listing 4 Code example'), isTrue);
    });

    test('does not flag regular text as captions', () {
      expect(PdfTextExtractor.looksLikeCaption('Regular paragraph text'), isFalse);
      expect(PdfTextExtractor.looksLikeCaption('The figure shows that'), isFalse);
    });

    test('cleans equation numbers from text', () {
      expect(PdfTextExtractor.cleanEquationText('E = mc^2 (1)'), equals('E = mc^2'));
      expect(PdfTextExtractor.cleanEquationText('x + y = z (2.3)'), equals('x + y = z'));
      expect(PdfTextExtractor.cleanEquationText('x + y = z (12)'), equals('x + y = z'));
      expect(PdfTextExtractor.cleanEquationText('plain equation'), equals('plain equation'));
    });
  });

  group('PdfReflowRenderer LaTeX conversion', () {
    test('converts Unicode Greek letters to LaTeX', () {
      expect(PdfReflowRenderer.textToTex('α'), equals(r'\alpha'));
      expect(PdfReflowRenderer.textToTex('β'), equals(r'\beta'));
      expect(PdfReflowRenderer.textToTex('γ'), equals(r'\gamma'));
      expect(PdfReflowRenderer.textToTex('Σ'), equals(r'\Sigma'));
      expect(PdfReflowRenderer.textToTex('Ω'), equals(r'\Omega'));
    });

    test('converts Unicode math operators to LaTeX', () {
      expect(PdfReflowRenderer.textToTex('∫'), equals(r'\int'));
      expect(PdfReflowRenderer.textToTex('∑'), equals(r'\sum'));
      expect(PdfReflowRenderer.textToTex('∏'), equals(r'\prod'));
      expect(PdfReflowRenderer.textToTex('√'), equals(r'\sqrt'));
      expect(PdfReflowRenderer.textToTex('∞'), equals(r'\infty'));
      expect(PdfReflowRenderer.textToTex('∂'), equals(r'\partial'));
      expect(PdfReflowRenderer.textToTex('∇'), equals(r'\nabla'));
    });

    test('converts Unicode relation symbols to LaTeX', () {
      expect(PdfReflowRenderer.textToTex('≈'), equals(r'\approx'));
      expect(PdfReflowRenderer.textToTex('≠'), equals(r'\neq'));
      expect(PdfReflowRenderer.textToTex('≤'), equals(r'\leq'));
      expect(PdfReflowRenderer.textToTex('≥'), equals(r'\geq'));
      expect(PdfReflowRenderer.textToTex('±'), equals(r'\pm'));
      expect(PdfReflowRenderer.textToTex('×'), equals(r'\times'));
    });

    test('converts Unicode set/logic symbols to LaTeX', () {
      expect(PdfReflowRenderer.textToTex('∈'), equals(r'\in'));
      expect(PdfReflowRenderer.textToTex('∀'), equals(r'\forall'));
      expect(PdfReflowRenderer.textToTex('∃'), equals(r'\exists'));
      expect(PdfReflowRenderer.textToTex('∪'), equals(r'\cup'));
      expect(PdfReflowRenderer.textToTex('∩'), equals(r'\cap'));
    });

    test('strips LaTeX delimiters', () {
      expect(PdfReflowRenderer.textToTex(r'\[ x^2 \]'), equals(r'x^2'));
      expect(PdfReflowRenderer.textToTex(r'$$ \frac{a}{b} $$'), equals(r'\frac{a}{b}'));
      expect(PdfReflowRenderer.textToTex(r'$ x $'), equals(r'x'));
    });

    test('handles mixed text with multiple symbols', () {
      final result = PdfReflowRenderer.textToTex('α + β = γ');
      expect(result, equals(r'\alpha + \beta = \gamma'));
    });

    test('handles plain text without math symbols', () {
      expect(PdfReflowRenderer.textToTex('hello world'), equals('hello world'));
      expect(PdfReflowRenderer.textToTex('x + y = z'), equals('x + y = z'));
    });

    test('handles arrow symbols', () {
      expect(PdfReflowRenderer.textToTex('→'), equals(r'\rightarrow'));
      expect(PdfReflowRenderer.textToTex('←'), equals(r'\leftarrow'));
      expect(PdfReflowRenderer.textToTex('⇒'), equals(r'\Rightarrow'));
    });
  });
}
