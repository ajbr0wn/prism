import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prism/widgets/soft_hyphen_text.dart';

/// Integration test that runs on a real Android device (via Firebase Test Lab)
/// to catch the "grey box" rendering bug: previously SoftHyphenText wrapped
/// SelectableText.rich in a LayoutBuilder which caused paragraphs to render
/// as empty grey rectangles on real devices.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SoftHyphenText paragraphs render with content-sized height',
      (tester) async {
    // Use representative book text with soft hyphens like our hyphenation
    // service would produce.
    const paragraphs = [
      'He looked at his own Soul with a Tele\u00ADscope. What seemed all '
          'irreg\u00ADu\u00ADlar, he saw and shewed to be beau\u00ADti\u00ADful '
          'Con\u00ADstel\u00ADla\u00ADtions; and he added to the '
          'Con\u00ADscious\u00ADness hid\u00ADden worlds within worlds.',
      'The justi\u00ADfi\u00ADca\u00ADtion of text in read\u00ADing '
          'appli\u00ADca\u00ADtions creates even mar\u00ADgins that '
          'im\u00ADprove read\u00ADabil\u00ADity for long-form con\u00ADtent.',
      'Soft hyphens are invi\u00ADsi\u00ADble until the text lay\u00ADout '
          'engine uses them for line break\u00ADing. At that point they '
          'should ren\u00ADder as vis\u00ADi\u00ADble hyphens at the end '
          'of the broken line.',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final text in paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SoftHyphenText(
                        textSpan: TextSpan(
                          text: text,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                        textAlign: TextAlign.justify,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Let the post-frame measurement and rebuild happen
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    final selectables = find.byType(SelectableText);
    expect(selectables, findsNWidgets(paragraphs.length));

    for (var i = 0; i < paragraphs.length; i++) {
      final renderBox = tester.renderObject<RenderBox>(selectables.at(i));
      // A paragraph of ~50+ words at 16px font and line-height 1.5 should
      // be well over 50px tall. If it collapses to a grey box, height
      // would be close to zero.
      expect(
        renderBox.size.height,
        greaterThan(50),
        reason: 'Paragraph $i collapsed to height ${renderBox.size.height} '
            '(expected > 50). This is the grey box rendering bug.',
      );
      // Width should match the column's available width (screen - 48 padding)
      expect(renderBox.size.width, greaterThan(100),
          reason: 'Paragraph $i has suspiciously narrow width: '
              '${renderBox.size.width}');
    }
  });
}
