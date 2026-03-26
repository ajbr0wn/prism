import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReadingSettings {
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final double horizontalMargins;
  final TextAlign textAlign;
  final bool continuousScroll;
  final bool paragraphIndent;

  const ReadingSettings({
    this.fontFamily = 'literata',
    this.fontSize = 18.0,
    this.lineHeight = 1.7,
    this.horizontalMargins = 28.0,
    this.textAlign = TextAlign.justify,
    this.continuousScroll = false,
    this.paragraphIndent = true,
  });

  ReadingSettings copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? horizontalMargins,
    TextAlign? textAlign,
    bool? continuousScroll,
    bool? paragraphIndent,
  }) {
    return ReadingSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalMargins: horizontalMargins ?? this.horizontalMargins,
      textAlign: textAlign ?? this.textAlign,
      continuousScroll: continuousScroll ?? this.continuousScroll,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
    );
  }

  /// Returns a TextStyle with the selected font applied.
  TextStyle get fontTextStyle {
    switch (fontFamily) {
      case 'literata':
        return GoogleFonts.literata();
      case 'merriweather':
        return GoogleFonts.merriweather();
      case 'lora':
        return GoogleFonts.lora();
      case 'sourceSerif4':
        return GoogleFonts.sourceSerif4();
      case 'serif':
        return const TextStyle(fontFamily: 'serif');
      case 'mono':
        return const TextStyle(fontFamily: 'monospace');
      case 'default':
      default:
        return const TextStyle(); // system sans-serif
    }
  }

  static const fontOptions = [
    ('default', 'Sans'),
    ('literata', 'Literata'),
    ('merriweather', 'Merri'),
    ('lora', 'Lora'),
    ('sourceSerif4', 'Source'),
    ('serif', 'Serif'),
    ('mono', 'Mono'),
  ];

  static const lineHeightOptions = [
    (1.3, 'Compact'),
    (1.6, 'Normal'),
    (2.0, 'Wide'),
  ];

  static const marginOptions = [
    (16.0, 'Narrow'),
    (28.0, 'Normal'),
    (44.0, 'Wide'),
  ];

  Map<String, dynamic> toJson() => {
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'horizontalMargins': horizontalMargins,
        'textAlign': textAlign.index,
        'continuousScroll': continuousScroll,
        'paragraphIndent': paragraphIndent,
      };

  factory ReadingSettings.fromJson(Map<String, dynamic> json) =>
      ReadingSettings(
        fontFamily: json['fontFamily'] as String? ?? 'literata',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.7,
        horizontalMargins:
            (json['horizontalMargins'] as num?)?.toDouble() ?? 28.0,
        textAlign: TextAlign
            .values[json['textAlign'] as int? ?? TextAlign.justify.index],
        continuousScroll: json['continuousScroll'] as bool? ?? false,
        paragraphIndent: json['paragraphIndent'] as bool? ?? true,
      );
}
