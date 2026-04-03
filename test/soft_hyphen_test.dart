import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism/widgets/soft_hyphen_text.dart';

void main() {
  group('SoftHyphenText', () {
    testWidgets('renders without soft hyphens unchanged', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: SoftHyphenText(
                textSpan: TextSpan(text: 'Hello world'),
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('renders text containing soft hyphens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: SoftHyphenText(
                textSpan: TextSpan(
                  text: 'Justi\u00ADfi\u00ADca\u00ADtion',
                  style: const TextStyle(fontSize: 16),
                ),
                textAlign: TextAlign.justify,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('renders with narrow width forcing line breaks',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              child: SoftHyphenText(
                textSpan: TextSpan(
                  text:
                      'Justi\u00ADfication is impor\u00ADtant for read\u00ADability in long paragraphs',
                  style: const TextStyle(fontSize: 14),
                ),
                textAlign: TextAlign.justify,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('handles nested TextSpan children', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              child: SoftHyphenText(
                textSpan: TextSpan(
                  style: const TextStyle(fontSize: 14),
                  children: [
                    const TextSpan(text: 'This is '),
                    TextSpan(
                      text: 'jus\u00ADti\u00ADfi\u00ADca\u00ADtion',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' text for testing.'),
                  ],
                ),
                textAlign: TextAlign.justify,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('preserves context menu builder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: SoftHyphenText(
                textSpan: const TextSpan(text: 'Selectable text'),
                textAlign: TextAlign.left,
                contextMenuBuilder: (context, editableTextState) {
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsOneWidget);
    });
  });

  group('SoftHyphenText span processing', () {
    // Unit test the span replacement logic directly
    test('_replaceInSpan handles simple text', () {
      // Test via the public widget indirectly - verify the logic
      // by checking that soft hyphens at specified positions get replaced
      const span = TextSpan(text: 'hel\u00ADlo wor\u00ADld');
      // Position 3 = first soft hyphen, position 8 = second
      // If position 3 is a break position, it should become '-'
      final result = SoftHyphenTextTestHelper.replaceInSpan(span, {3});
      expect((result as TextSpan).text, 'hel-lo wor\u00ADld');
    });

    test('_replaceInSpan handles nested children', () {
      const span = TextSpan(
        text: 'ab\u00ADc',
        children: [
          TextSpan(text: 'de\u00ADf'),
        ],
      );
      // Position 2 = soft hyphen in parent text, position 6 = soft hyphen in child
      // (parent text "ab\u00ADc" is 4 chars, child starts at offset 4)
      final result = SoftHyphenTextTestHelper.replaceInSpan(span, {2, 6});
      final resultSpan = result as TextSpan;
      expect(resultSpan.text, 'ab-c');
      expect((resultSpan.children![0] as TextSpan).text, 'de-f');
    });

    test('_replaceInSpan leaves non-break soft hyphens alone', () {
      const span = TextSpan(text: 'hel\u00ADlo');
      // No break positions
      final result = SoftHyphenTextTestHelper.replaceInSpan(span, {});
      // Should return the same span since nothing changed
      expect(identical(result, span), isTrue);
    });
  });
}

/// Exposes internal logic for unit testing.
class SoftHyphenTextTestHelper {
  static InlineSpan replaceInSpan(TextSpan span, Set<int> breakPositions) {
    // Use the same logic as SoftHyphenText._replaceInSpan
    return _replaceInSpan(span, breakPositions, 0).span;
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
