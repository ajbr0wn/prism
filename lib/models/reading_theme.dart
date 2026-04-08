import 'package:flutter/material.dart';

enum ShaderEffect {
  none,
  holographic,
  aurora,
  opalescent,
  prismatic,
  ember,
  mandelbrot,
  julia,
  oilSlick,
  voronoi,
  plasma,
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

  // Text shadow/underlay for readability over effects
  final Color? textShadowColor;
  final double textShadowBlur;

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
    this.textShadowColor,
    this.textShadowBlur = 0.0,
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
    Color? textShadowColor,
    double? textShadowBlur,
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
      textShadowColor: textShadowColor ?? this.textShadowColor,
      textShadowBlur: textShadowBlur ?? this.textShadowBlur,
    );
  }

  // Shader mode index for the GLSL shader (none = -1, holographic = 0, etc.)
  double get shaderModeValue => shaderEffect == ShaderEffect.none
      ? -1.0
      : (shaderEffect.index - 1).toDouble();

  /// Whether this theme has a dark background.
  bool get isDark => backgroundColor.computeLuminance() < 0.5;

  /// Return a version of this theme in the requested mode.
  /// If the theme is already in the requested mode, returns itself.
  ReadingTheme withDarkMode(bool dark) {
    if (dark == isDark) return this;
    // Invert lightness relative to current values rather than using
    // fixed targets. This preserves the theme's aesthetic (e.g. brown
    // text stays brown-ish, not pink).
    return copyWith(
      backgroundColor: _invertLightness(backgroundColor),
      textColor: _invertLightness(textColor),
      headingColor: _invertLightness(headingColor),
      accentColor: _invertLightness(accentColor),
      linkColor: _invertLightness(linkColor),
    );
  }

  /// Invert lightness: 0.1 → 0.9, 0.8 → 0.2, etc.
  /// Preserves hue and saturation so colors stay in family.
  static Color _invertLightness(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((1.0 - hsl.lightness).clamp(0.05, 0.95)).toColor();
  }

  static Color _setLightness(Color c, double l) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(l.clamp(0.0, 1.0)).toColor();
  }

  static Color _adjustLightness(Color c, double target) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(target.clamp(0.0, 1.0)).toColor();
  }

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
        'textShadowColor': textShadowColor?.toARGB32(),
        'textShadowBlur': textShadowBlur,
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
        textShadowColor: json['textShadowColor'] != null
            ? Color(json['textShadowColor'] as int)
            : null,
        textShadowBlur:
            (json['textShadowBlur'] as num?)?.toDouble() ?? 0.0,
      );

  // ── Built-in presets ──

  static const silverware = ReadingTheme(
    id: 'silverware',
    name: 'Silverware',
    isBuiltIn: true,
    backgroundColor: Color(0xFFB4CBBE),
    textColor: Color(0xFF341F1F),
    headingColor: Color(0xFF1A0E82),
    accentColor: Color(0xFFACA169),
    linkColor: Color(0xFFAD407C),
    shaderEffect: ShaderEffect.plasma,
    shaderIntensity: 0.14,
    vignetteIntensity: 0.15,
  );

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

  static const classic = ReadingTheme(
    id: 'classic',
    name: 'Classic',
    isBuiltIn: true,
    backgroundColor: Color(0xFF1e1e1e),
    textColor: Color(0xFFd4d4d4),
    headingColor: Color(0xFFffffff),
    accentColor: Color(0xFF569cd6),
    linkColor: Color(0xFF6cb6ff),
  );

  static const deepFractal = ReadingTheme(
    id: 'deep-fractal',
    name: 'Deep Fractal',
    isBuiltIn: true,
    backgroundColor: Color(0xFF080812),
    textColor: Color(0xFFd0cce0),
    headingColor: Color(0xFFe0c8f0),
    accentColor: Color(0xFF9060d0),
    linkColor: Color(0xFFb080e8),
    shaderEffect: ShaderEffect.mandelbrot,
    shaderIntensity: 0.08,
    vignetteIntensity: 0.15,
  );

  static const dreamscape = ReadingTheme(
    id: 'dreamscape',
    name: 'Dreamscape',
    isBuiltIn: true,
    backgroundColor: Color(0xFF0a0818),
    textColor: Color(0xFFc8c0e0),
    headingColor: Color(0xFFe8b0d0),
    accentColor: Color(0xFFd070a0),
    linkColor: Color(0xFFe090b8),
    shaderEffect: ShaderEffect.julia,
    shaderIntensity: 0.07,
    vignetteIntensity: 0.12,
  );

  static const petrichor = ReadingTheme(
    id: 'petrichor',
    name: 'Petrichor',
    isBuiltIn: true,
    backgroundColor: Color(0xFF0e1218),
    textColor: Color(0xFFc8d0d8),
    headingColor: Color(0xFFa0d8e8),
    accentColor: Color(0xFF50a0b8),
    linkColor: Color(0xFF70b8d0),
    shaderEffect: ShaderEffect.oilSlick,
    shaderIntensity: 0.08,
    vignetteIntensity: 0.1,
  );

  static const crystalline = ReadingTheme(
    id: 'crystalline',
    name: 'Crystalline',
    isBuiltIn: true,
    backgroundColor: Color(0xFF10101a),
    textColor: Color(0xFFc0c8d8),
    headingColor: Color(0xFFa8c0e0),
    accentColor: Color(0xFF5080c0),
    linkColor: Color(0xFF6898d8),
    shaderEffect: ShaderEffect.voronoi,
    shaderIntensity: 0.06,
    vignetteIntensity: 0.1,
  );

  static const neonDream = ReadingTheme(
    id: 'neon-dream',
    name: 'Neon Dream',
    isBuiltIn: true,
    backgroundColor: Color(0xFF0a0a14),
    textColor: Color(0xFFd8d0e8),
    headingColor: Color(0xFFf0a0f0),
    accentColor: Color(0xFFd060e0),
    linkColor: Color(0xFFe080f0),
    shaderEffect: ShaderEffect.plasma,
    shaderIntensity: 0.06,
    vignetteIntensity: 0.12,
  );

  static const List<ReadingTheme> builtInThemes = [
    silverware,
    midnightPrism,
    opal,
    northernLights,
    ember,
    prismatic,
    moonstone,
    deepFractal,
    dreamscape,
    petrichor,
    crystalline,
    neonDream,
    classic,
  ];

  /// Preset color palettes organized by shader effect.
  /// Each palette is a tuple of (name, bg, text, heading, accent, link).
  static const Map<ShaderEffect, List<(String, Color, Color, Color, Color, Color)>> palettes = {
    ShaderEffect.holographic: [
      ('Midnight', Color(0xFF0a0a14), Color(0xFFe0dfe8), Color(0xFFc8b8f0), Color(0xFF7c6fef), Color(0xFF9d93f0)),
      ('Ocean', Color(0xFF081018), Color(0xFFc8d8e8), Color(0xFF80c0e0), Color(0xFF4090c0), Color(0xFF60a8d0)),
      ('Rose', Color(0xFF140a10), Color(0xFFe8d0e0), Color(0xFFf0a0c0), Color(0xFFd06090), Color(0xFFe080a8)),
      ('Forest', Color(0xFF0a1208), Color(0xFFd0e0c8), Color(0xFF90d0a0), Color(0xFF50a060), Color(0xFF70b880)),
    ],
    ShaderEffect.aurora: [
      ('Nordic', Color(0xFF0d1117), Color(0xFFc9d1d9), Color(0xFF7ee8be), Color(0xFF58a6ff), Color(0xFF79c0ff)),
      ('Violet', Color(0xFF100a18), Color(0xFFd8c8e8), Color(0xFFc090f0), Color(0xFF9060d0), Color(0xFFb080e0)),
      ('Emerald', Color(0xFF081410), Color(0xFFc8e0d0), Color(0xFF60d890), Color(0xFF30b060), Color(0xFF48c878)),
    ],
    ShaderEffect.oilSlick: [
      ('Petrol', Color(0xFF0e1218), Color(0xFFc8d0d8), Color(0xFFa0d8e8), Color(0xFF50a0b8), Color(0xFF70b8d0)),
      ('Copper', Color(0xFF141008), Color(0xFFe0d0b8), Color(0xFFd8a870), Color(0xFFb07830), Color(0xFFc89050)),
      ('Chrome', Color(0xFF101014), Color(0xFFd8d8e0), Color(0xFFb0b0c8), Color(0xFF7878a0), Color(0xFF9898b8)),
    ],
    ShaderEffect.mandelbrot: [
      ('Cosmic', Color(0xFF080812), Color(0xFFd0cce0), Color(0xFFe0c8f0), Color(0xFF9060d0), Color(0xFFb080e8)),
      ('Inferno', Color(0xFF120808), Color(0xFFe0ccc8), Color(0xFFf0c080), Color(0xFFd06830), Color(0xFFe88848)),
      ('Arctic', Color(0xFF081018), Color(0xFFc8d8e8), Color(0xFF80b8e0), Color(0xFF4888c0), Color(0xFF60a0d8)),
    ],
    ShaderEffect.julia: [
      ('Dream', Color(0xFF0a0818), Color(0xFFc8c0e0), Color(0xFFe8b0d0), Color(0xFFd070a0), Color(0xFFe090b8)),
      ('Nebula', Color(0xFF0a0a18), Color(0xFFc8c8e0), Color(0xFFa0a0f0), Color(0xFF6868d0), Color(0xFF8888e8)),
      ('Amber', Color(0xFF141008), Color(0xFFe0d8c0), Color(0xFFe8c880), Color(0xFFc09030), Color(0xFFd8a848)),
    ],
    ShaderEffect.plasma: [
      ('Neon', Color(0xFF0a0a14), Color(0xFFd8d0e8), Color(0xFFf0a0f0), Color(0xFFd060e0), Color(0xFFe080f0)),
      ('Vapor', Color(0xFF080814), Color(0xFFd0d0e8), Color(0xFFa0e0f0), Color(0xFF50b8d0), Color(0xFF70d0e8)),
      ('Lava', Color(0xFF140808), Color(0xFFe8d0c8), Color(0xFFf09060), Color(0xFFe06020), Color(0xFFf07838)),
    ],
    ShaderEffect.ember: [
      ('Hearth', Color(0xFF1a1210), Color(0xFFe8d5c4), Color(0xFFf0a868), Color(0xFFd47030), Color(0xFFe08848)),
      ('Crimson', Color(0xFF180808), Color(0xFFe0c8c8), Color(0xFFf07070), Color(0xFFd03030), Color(0xFFe84848)),
      ('Gold', Color(0xFF141008), Color(0xFFe0d8c0), Color(0xFFe8d080), Color(0xFFc0a030), Color(0xFFd8b848)),
    ],
    ShaderEffect.voronoi: [
      ('Crystal', Color(0xFF10101a), Color(0xFFc0c8d8), Color(0xFFa8c0e0), Color(0xFF5080c0), Color(0xFF6898d8)),
      ('Jade', Color(0xFF081410), Color(0xFFc0d8c8), Color(0xFF80c8a0), Color(0xFF409868), Color(0xFF58b080)),
      ('Amethyst', Color(0xFF120a18), Color(0xFFd0c0e0), Color(0xFFc098e0), Color(0xFF8860c0), Color(0xFFA078D8)),
    ],
    ShaderEffect.prismatic: [
      ('Spectrum', Color(0xFFffffff), Color(0xFF2d2d2d), Color(0xFF4a00e0), Color(0xFF8e2de2), Color(0xFF6a1cb0)),
      ('Pastel', Color(0xFFF8F0FF), Color(0xFF383040), Color(0xFF7050a0), Color(0xFF9070c0), Color(0xFF7858a8)),
    ],
    ShaderEffect.opalescent: [
      ('Pearl', Color(0xFFFAF5EB), Color(0xFF3a3530), Color(0xFF5c4f3f), Color(0xFF8b7355), Color(0xFF6b5a42)),
      ('Moonlit', Color(0xFF121820), Color(0xFFb8c4d0), Color(0xFFd0e0f0), Color(0xFF6090c0), Color(0xFF80b0e0)),
    ],
  };
}
