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
  final bool darkMode;

  const ReadingSettings({
    this.fontFamily = 'literata',
    this.fontSize = 16.0,
    this.lineHeight = 1.7,
    this.horizontalMargins = 28.0,
    this.textAlign = TextAlign.justify,
    this.continuousScroll = false,
    this.paragraphIndent = true,
    this.darkMode = true,
  });

  ReadingSettings copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? horizontalMargins,
    TextAlign? textAlign,
    bool? continuousScroll,
    bool? paragraphIndent,
    bool? darkMode,
  }) {
    return ReadingSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalMargins: horizontalMargins ?? this.horizontalMargins,
      textAlign: textAlign ?? this.textAlign,
      continuousScroll: continuousScroll ?? this.continuousScroll,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      darkMode: darkMode ?? this.darkMode,
    );
  }

  /// Apply the selected font to a base TextStyle.
  /// Uses GoogleFonts.xxx(textStyle: base) which is the correct way
  /// to ensure the font family is properly applied and downloaded.
  TextStyle applyFont(TextStyle base) {
    switch (fontFamily) {
      case 'literata':
        return GoogleFonts.literata(textStyle: base);
      case 'merriweather':
        return GoogleFonts.merriweather(textStyle: base);
      case 'lora':
        return GoogleFonts.lora(textStyle: base);
      case 'sourceSerif4':
        return GoogleFonts.sourceSerif4(textStyle: base);
      case 'serif':
        return base.copyWith(fontFamily: 'serif');
      case 'mono':
        return base.copyWith(fontFamily: 'monospace');
      case 'default':
      default:
        return base;
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
    (56.0, 'Wide'),
  ];

  Map<String, dynamic> toJson() => {
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'horizontalMargins': horizontalMargins,
        'textAlign': textAlign.index,
        'continuousScroll': continuousScroll,
        'paragraphIndent': paragraphIndent,
        'darkMode': darkMode,
      };

  factory ReadingSettings.fromJson(Map<String, dynamic> json) =>
      ReadingSettings(
        fontFamily: json['fontFamily'] as String? ?? 'literata',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.7,
        horizontalMargins:
            (json['horizontalMargins'] as num?)?.toDouble() ?? 28.0,
        textAlign: TextAlign
            .values[json['textAlign'] as int? ?? TextAlign.justify.index],
        continuousScroll: json['continuousScroll'] as bool? ?? false,
        paragraphIndent: json['paragraphIndent'] as bool? ?? true,
        darkMode: json['darkMode'] as bool? ?? true,
      );
}
