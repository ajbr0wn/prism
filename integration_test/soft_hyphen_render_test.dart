import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prism/widgets/soft_hyphen_text.dart';

/// Comprehensive integration tests for soft hyphen rendering.
///
/// Runs on a real Android device via Firebase Test Lab to catch issues
/// that widget tests miss (different text layout engines, font metrics, etc.).
///
/// Five levels of verification:
///   1. Grey box regression — paragraphs render with real height
///   2. Flutter breaks at soft hyphens — prerequisite for the whole approach
///   3. Detection finds break positions — the algorithm works on this device
///   4. Processed span contains visible hyphens — end-to-end pipeline check
///   5. Pixel inspection — visible hyphen ink at line ends

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Shared constants for controlled layout.
  const testStyle = TextStyle(
    fontSize: 18,
    height: 1.5,
    color: Color(0xFF000000),
    fontFamily: 'Roboto',
  );
  const testWidth = 200.0;
  // Text with many soft hyphens — at 200px / 18px font, several must break.
  const testText =
      'The justi\u00ADfi\u00ADca\u00ADtion of text in read\u00ADing '
      'appli\u00ADca\u00ADtions creates even mar\u00ADgins that '
      'im\u00ADprove read\u00ADabil\u00ADity for long-form con\u00ADtent.';

  /// Helper: pump a SoftHyphenText widget and wait for post-frame rebuild.
  Future<SoftHyphenTextState> pumpSoftHyphenText(
    WidgetTester tester, {
    String text = testText,
    double width = testWidth,
    TextStyle style = testStyle,
    GlobalKey<SoftHyphenTextState>? stateKey,
  }) async {
    final key = stateKey ?? GlobalKey<SoftHyphenTextState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: width,
              child: SoftHyphenText(
                key: key,
                textSpan: TextSpan(text: text, style: style),
                textAlign: TextAlign.justify,
              ),
            ),
          ),
        ),
      ),
    );
    // Let the post-frame measurement callback fire and rebuild.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return key.currentState!;
  }

  // ── Test 1: Grey box regression ──────────────────────────────────────────

  testWidgets('paragraphs render with content-sized height (grey box check)',
      (tester) async {
    const paragraphs = [
      'He looked at his own Soul with a Tele\u00ADscope. What seemed all '
          'irreg\u00ADu\u00ADlar, he saw and shewed to be beau\u00ADti\u00ADful '
          'Con\u00ADstel\u00ADla\u00ADtions; and he added to the '
          'Con\u00ADscious\u00ADness hid\u00ADden worlds within worlds.',
      testText,
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
                        textSpan: TextSpan(text: text, style: testStyle),
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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final selectables = find.byType(SelectableText);
    expect(selectables, findsNWidgets(paragraphs.length));

    for (var i = 0; i < paragraphs.length; i++) {
      final renderBox = tester.renderObject<RenderBox>(selectables.at(i));
      expect(
        renderBox.size.height,
        greaterThan(50),
        reason: 'Paragraph $i collapsed to height ${renderBox.size.height}. '
            'This is the grey box rendering bug.',
      );
    }
  });

  // ── Test 2: Flutter breaks at soft hyphens ───────────────────────────────

  testWidgets('Flutter line-breaks at soft hyphens (prerequisite)',
      (tester) async {
    // Render a plain SelectableText (no SoftHyphenText wrapper) with a
    // long word containing a soft hyphen, at a width too narrow for the
    // full word. If Flutter breaks at the soft hyphen, we get multiple
    // lines. If it doesn't, the whole SoftHyphenText approach is moot.
    const word = 'Abcdefghijklmnop\u00ADqrstuvwxyzabcdef';
    const style = TextStyle(fontSize: 18, height: 1.5, fontFamily: 'Roboto');
    const narrowWidth = 150.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: narrowWidth,
              child: SelectableText(
                word,
                style: style,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final renderBox =
        tester.renderObject<RenderBox>(find.byType(SelectableText));
    final singleLineHeight = style.fontSize! * style.height!;

    expect(
      renderBox.size.height,
      greaterThan(singleLineHeight * 1.5),
      reason: 'Text should wrap to multiple lines via soft hyphen break. '
          'Height: ${renderBox.size.height}, single line: $singleLineHeight. '
          'If this fails, Flutter does not break at soft hyphens on this '
          'device/engine and the entire SoftHyphenText approach is wrong.',
    );
  });

  // ── Test 3: Detection finds break positions ──────────────────────────────

  testWidgets('detection finds soft hyphens at line breaks', (tester) async {
    final state = await pumpSoftHyphenText(tester);

    expect(
      state.breakPositions,
      isNotEmpty,
      reason: 'At ${testWidth}px with 18px Roboto, the test text must break '
          'at least one soft hyphen. If empty, the detection algorithm '
          '(RenderEditable.getBoxesForSelection from actual render tree) '
          'does not work on this device.',
    );
  });

  // ── Test 4: Processed span has visible hyphens ───────────────────────────

  testWidgets('processed span replaces soft hyphens with visible hyphens',
      (tester) async {
    final state = await pumpSoftHyphenText(tester);

    final processed = state.processedSpan;
    expect(processed, isNotNull,
        reason: 'Widget should have rebuilt with a processed span');

    final plainText = processed!.toPlainText();
    expect(
      plainText.contains('-'),
      isTrue,
      reason: 'Processed text should contain at least one visible hyphen "-". '
          'Got: "$plainText"',
    );

    // The original text has no hard hyphens (only soft hyphens and
    // "long-form" which has one). Count that at least one extra appeared.
    final inputHardHyphens = '-'.allMatches(testText).length;
    final outputHardHyphens = '-'.allMatches(plainText).length;
    expect(
      outputHardHyphens,
      greaterThan(inputHardHyphens),
      reason: 'Should have more "-" in output than input. '
          'Input has $inputHardHyphens, output has $outputHardHyphens.',
    );
  });

  // ── Test 5: Pixel inspection for visible hyphen glyphs ─────────────────

  testWidgets('visible hyphen ink differs from unprocessed render',
      (tester) async {
    // Strategy: comparative pixel diff.
    //
    // Render A: SoftHyphenText (should replace \u00AD with "-" at breaks)
    // Render B: Plain SelectableText with original \u00AD text (no processing)
    //
    // Both use LEFT-ALIGNED text so lines don't stretch to fill the width.
    // If the fix works, A has visible "-" glyphs where B has invisible \u00AD.
    // This makes the images differ. If the fix doesn't work, both images are
    // identical (both rendering \u00AD as nothing).
    //
    // We count differing pixels. Non-zero diff = fix is working.

    const bgColor = Color(0xFFFFFFFF);
    const style = TextStyle(
      fontSize: 18,
      height: 1.5,
      color: Color(0xFF000000),
      fontFamily: 'Roboto',
    );

    // Helper to render a widget in a RepaintBoundary and capture pixels.
    Future<(ui.Image, List<int>)> capture(
      WidgetTester tester,
      Widget child,
    ) async {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: bgColor,
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: RepaintBoundary(
                key: boundaryKey,
                child: Container(
                  width: testWidth,
                  color: bgColor,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (image, byteData!.buffer.asUint8List().toList());
    }

    // Render A: SoftHyphenText (the widget under test).
    final stateKey = GlobalKey<SoftHyphenTextState>();
    final (imageA, pixelsA) = await capture(
      tester,
      SoftHyphenText(
        key: stateKey,
        textSpan: const TextSpan(text: testText, style: style),
        textAlign: TextAlign.left,
      ),
    );

    // Check that detection actually found breaks (prerequisite).
    final state = stateKey.currentState!;
    if (state.breakPositions.isEmpty) {
      fail('Pixel test cannot proceed: detection found no break positions. '
          'Fix detection first (test 3 should have caught this).');
    }

    // Render B: plain SelectableText with the same \u00AD text, unprocessed.
    final (imageB, pixelsB) = await capture(
      tester,
      const SelectableText.rich(
        TextSpan(text: testText, style: style),
        textAlign: TextAlign.left,
      ),
    );

    // Count pixels that differ between the two renders.
    final minLen =
        pixelsA.length < pixelsB.length ? pixelsA.length : pixelsB.length;
    var differingPixels = 0;
    for (var i = 0; i < minLen; i += 4) {
      // Compare RGB (skip alpha).
      if (pixelsA[i] != pixelsB[i] ||
          pixelsA[i + 1] != pixelsB[i + 1] ||
          pixelsA[i + 2] != pixelsB[i + 2]) {
        differingPixels++;
      }
    }

    expect(
      differingPixels,
      greaterThan(0),
      reason: 'SoftHyphenText render is pixel-identical to unprocessed render. '
          'This means visible hyphens are NOT appearing despite detection '
          'finding ${state.breakPositions.length} break positions. '
          'Images: ${imageA.width}x${imageA.height} vs '
          '${imageB.width}x${imageB.height}.',
    );
  });
}
