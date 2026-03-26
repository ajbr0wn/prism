import 'package:flutter/material.dart';

class ReadingSettings {
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final double horizontalMargins;
  final TextAlign textAlign;
  final bool continuousScroll;

  const ReadingSettings({
    this.fontFamily = 'default',
    this.fontSize = 18.0,
    this.lineHeight = 1.7,
    this.horizontalMargins = 28.0,
    this.textAlign = TextAlign.center,
    this.continuousScroll = false,
  });

  ReadingSettings copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? horizontalMargins,
    TextAlign? textAlign,
    bool? continuousScroll,
  }) {
    return ReadingSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalMargins: horizontalMargins ?? this.horizontalMargins,
      textAlign: textAlign ?? this.textAlign,
      continuousScroll: continuousScroll ?? this.continuousScroll,
    );
  }

  /// Map font family name to actual Flutter font family string.
  String? get effectiveFontFamily {
    switch (fontFamily) {
      case 'serif':
        return 'serif';
      case 'mono':
        return 'monospace';
      case 'default':
      default:
        return null; // system default (Roboto on Android)
    }
  }

  static const fontOptions = [
    ('default', 'Sans'),
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
      };

  factory ReadingSettings.fromJson(Map<String, dynamic> json) =>
      ReadingSettings(
        fontFamily: json['fontFamily'] as String? ?? 'default',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.7,
        horizontalMargins:
            (json['horizontalMargins'] as num?)?.toDouble() ?? 28.0,
        textAlign:
            TextAlign.values[json['textAlign'] as int? ?? TextAlign.center.index],
        continuousScroll: json['continuousScroll'] as bool? ?? false,
      );
}
