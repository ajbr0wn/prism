import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism/widgets/soft_hyphen_text.dart';

/// Reproduces the "grey box" bug: wrapping SelectableText.rich in a
/// LayoutBuilder caused paragraph rendering to collapse on real devices.
void main() {
  testWidgets('many paragraphs in a scroll view all render with text',
      (tester) async {
    const longText =
        'This is a multi-paragraph reading experience with justi\u00ADfi\u00ADca\u00ADtion '
        'and soft hyphens inter\u00ADspersed through\u00ADout the content.';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 10; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SoftHyphenText(
                      textSpan: TextSpan(
                        text: longText,
                        style: const TextStyle(fontSize: 14),
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // All 10 paragraphs should be findable
    expect(find.byType(SelectableText), findsNWidgets(10));

    // All of them should have content-sized heights
    final allBoxes = find.byType(SelectableText);
    for (var i = 0; i < 10; i++) {
      final renderBox = tester.renderObject<RenderBox>(allBoxes.at(i));
      expect(renderBox.size.height, greaterThan(30),
          reason:
              'Paragraph $i has collapsed height: ${renderBox.size.height}');
    }
  });

  testWidgets('paragraph in unbounded-height Column renders properly',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SoftHyphenText(
                    textSpan: TextSpan(
                      text:
                          'A long paragraph with justi\u00ADfi\u00ADca\u00ADtion '
                          'that should wrap across multiple lines and render '
                          'text content visibly in the widget tree.',
                      style: TextStyle(fontSize: 14),
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final renderBox = tester.renderObject<RenderBox>(find.byType(SelectableText));
    expect(renderBox.size.height, greaterThan(30));
  });
}
