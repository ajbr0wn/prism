import 'package:flutter/material.dart';

enum ShaderEffect {
  none,
  holographic,
  aurora,
  opalescent,
  prismatic,
  ember,
}

class ReadingTheme {
  final String id;
  final String name;
  final bool isBuiltIn;

  // Background
  final Color backgroundColor;
  final List<Color>? gradientColors;
  final double gradientAngle;

  // Text
  final Color textColor;
  final Color headingColor;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;

  // Accents
  final Color accentColor;
  final Color linkColor;

  // Effects
  final ShaderEffect shaderEffect;
  final double shaderIntensity;
  final double shaderSpeed;

  // Atmosphere
  final double vignetteIntensity;

  const ReadingTheme({
    required this.id,
    required this.name,
    this.isBuiltIn = false,
    required this.backgroundColor,
    this.gradientColors,
    this.gradientAngle = 135.0,
    required this.textColor,
    required this.headingColor,
    this.fontSize = 18.0,
    this.lineHeight = 1.7,
    this.fontFamily = 'serif',
    required this.accentColor,
    required this.linkColor,
    this.shaderEffect = ShaderEffect.none,
    this.shaderIntensity = 0.08,
    this.shaderSpeed = 1.0,
    this.vignetteIntensity = 0.0,
  });

  ReadingTheme copyWith({
    String? id,
    String? name,
    bool? isBuiltIn,
    Color? backgroundColor,
    List<Color>? gradientColors,
    double? gradientAngle,
    Color? textColor,
    Color? headingColor,
    double? fontSize,
    double? lineHeight,
    String? fontFamily,
    Color? accentColor,
    Color? linkColor,
    ShaderEffect? shaderEffect,
    double? shaderIntensity,
    double? shaderSpeed,
    double? vignetteIntensity,
  }) {
    return ReadingTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      gradientColors: gradientColors ?? this.gradientColors,
      gradientAngle: gradientAngle ?? this.gradientAngle,
      textColor: textColor ?? this.textColor,
      headingColor: headingColor ?? this.headingColor,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: fontFamily ?? this.fontFamily,
      accentColor: accentColor ?? this.accentColor,
      linkColor: linkColor ?? this.linkColor,
      shaderEffect: shaderEffect ?? this.shaderEffect,
      shaderIntensity: shaderIntensity ?? this.shaderIntensity,
      shaderSpeed: shaderSpeed ?? this.shaderSpeed,
      vignetteIntensity: vignetteIntensity ?? this.vignetteIntensity,
    );
  }

  // Shader mode index for the GLSL shader (none = -1, holographic = 0, etc.)
  double get shaderModeValue => shaderEffect == ShaderEffect.none
      ? -1.0
      : (shaderEffect.index - 1).toDouble();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isBuiltIn': isBuiltIn,
        'backgroundColor': backgroundColor.toARGB32(),
        'gradientColors': gradientColors?.map((c) => c.toARGB32()).toList(),
        'gradientAngle': gradientAngle,
        'textColor': textColor.toARGB32(),
        'headingColor': headingColor.toARGB32(),
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'fontFamily': fontFamily,
        'accentColor': accentColor.toARGB32(),
        'linkColor': linkColor.toARGB32(),
        'shaderEffect': shaderEffect.name,
        'shaderIntensity': shaderIntensity,
        'shaderSpeed': shaderSpeed,
        'vignetteIntensity': vignetteIntensity,
      };

  factory ReadingTheme.fromJson(Map<String, dynamic> json) => ReadingTheme(
        id: json['id'] as String,
        name: json['name'] as String,
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
        backgroundColor: Color(json['backgroundColor'] as int),
        gradientColors: (json['gradientColors'] as List<dynamic>?)
            ?.map((v) => Color(v as int))
            .toList(),
        gradientAngle: (json['gradientAngle'] as num?)?.toDouble() ?? 135.0,
        textColor: Color(json['textColor'] as int),
        headingColor: Color(json['headingColor'] as int),
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.7,
        fontFamily: json['fontFamily'] as String? ?? 'serif',
        accentColor: Color(json['accentColor'] as int),
        linkColor: Color(json['linkColor'] as int),
        shaderEffect: ShaderEffect.values.firstWhere(
          (e) => e.name == json['shaderEffect'],
          orElse: () => ShaderEffect.none,
        ),
        shaderIntensity:
            (json['shaderIntensity'] as num?)?.toDouble() ?? 0.08,
        shaderSpeed: (json['shaderSpeed'] as num?)?.toDouble() ?? 1.0,
        vignetteIntensity:
            (json['vignetteIntensity'] as num?)?.toDouble() ?? 0.0,
      );

  // ── Built-in presets ──

  static const midnightPrism = ReadingTheme(
    id: 'midnight-prism',
    name: 'Midnight Prism',
    isBuiltIn: true,
    backgroundColor: Color(0xFF0a0a14),
    textColor: Color(0xFFe0dfe8),
    headingColor: Color(0xFFc8b8f0),
    accentColor: Color(0xFF7c6fef),
    linkColor: Color(0xFF9d93f0),
    shaderEffect: ShaderEffect.holographic,
    shaderIntensity: 0.07,
    vignetteIntensity: 0.15,
  );

  static const opal = ReadingTheme(
    id: 'opal',
    name: 'Opal',
    isBuiltIn: true,
    backgroundColor: Color(0xFFFAF5EB),
    textColor: Color(0xFF3a3530),
    headingColor: Color(0xFF5c4f3f),
    accentColor: Color(0xFF8b7355),
    linkColor: Color(0xFF6b5a42),
    shaderEffect: ShaderEffect.opalescent,
    shaderIntensity: 0.05,
  );

  static const northernLights = ReadingTheme(
    id: 'northern-lights',
    name: 'Northern Lights',
    isBuiltIn: true,
    backgroundColor: Color(0xFF0d1117),
    textColor: Color(0xFFc9d1d9),
    headingColor: Color(0xFF7ee8be),
    accentColor: Color(0xFF58a6ff),
    linkColor: Color(0xFF79c0ff),
    shaderEffect: ShaderEffect.aurora,
    shaderIntensity: 0.09,
    vignetteIntensity: 0.12,
  );

  static const ember = ReadingTheme(
    id: 'ember',
    name: 'Ember',
    isBuiltIn: true,
    backgroundColor: Color(0xFF1a1210),
    textColor: Color(0xFFe8d5c4),
    headingColor: Color(0xFFf0a868),
    accentColor: Color(0xFFd47030),
    linkColor: Color(0xFFe08848),
    shaderEffect: ShaderEffect.ember,
    shaderIntensity: 0.07,
    vignetteIntensity: 0.2,
  );

  static const prismatic = ReadingTheme(
    id: 'prismatic',
    name: 'Prismatic',
    isBuiltIn: true,
    backgroundColor: Color(0xFFffffff),
    textColor: Color(0xFF2d2d2d),
    headingColor: Color(0xFF4a00e0),
    accentColor: Color(0xFF8e2de2),
    linkColor: Color(0xFF6a1cb0),
    shaderEffect: ShaderEffect.prismatic,
    shaderIntensity: 0.04,
  );

  static const moonstone = ReadingTheme(
    id: 'moonstone',
    name: 'Moonstone',
    isBuiltIn: true,
    backgroundColor: Color(0xFF121820),
    textColor: Color(0xFFb8c4d0),
    headingColor: Color(0xFFd0e0f0),
    accentColor: Color(0xFF6090c0),
    linkColor: Color(0xFF80b0e0),
    shaderEffect: ShaderEffect.holographic,
    shaderIntensity: 0.05,
    vignetteIntensity: 0.1,
  );

  static const classicDark = ReadingTheme(
    id: 'classic-dark',
    name: 'Classic Dark',
    isBuiltIn: true,
    backgroundColor: Color(0xFF1e1e1e),
    textColor: Color(0xFFd4d4d4),
    headingColor: Color(0xFFffffff),
    accentColor: Color(0xFF569cd6),
    linkColor: Color(0xFF6cb6ff),
  );

  static const classicLight = ReadingTheme(
    id: 'classic-light',
    name: 'Classic Light',
    isBuiltIn: true,
    backgroundColor: Color(0xFFffffff),
    textColor: Color(0xFF333333),
    headingColor: Color(0xFF111111),
    accentColor: Color(0xFF0066cc),
    linkColor: Color(0xFF0055aa),
  );

  static const List<ReadingTheme> builtInThemes = [
    midnightPrism,
    opal,
    northernLights,
    ember,
    prismatic,
    moonstone,
    classicDark,
    classicLight,
  ];
}
