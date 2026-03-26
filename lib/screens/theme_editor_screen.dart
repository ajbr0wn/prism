import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reading_theme.dart';
import '../services/theme_service.dart';
import '../widgets/shader_background.dart';

class ThemeEditorScreen extends StatefulWidget {
  final ReadingTheme? baseTheme; // null = new theme, non-null = edit existing

  const ThemeEditorScreen({super.key, this.baseTheme});

  @override
  State<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends State<ThemeEditorScreen> {
  late String _name;
  late Color _backgroundColor;
  late Color _textColor;
  late Color _headingColor;
  late Color _accentColor;
  late Color _linkColor;
  late ShaderEffect _shaderEffect;
  late double _shaderIntensity;
  late double _shaderSpeed;
  late double _vignetteIntensity;

  @override
  void initState() {
    super.initState();
    final base = widget.baseTheme ?? ReadingTheme.midnightPrism;
    _name = widget.baseTheme?.name ?? 'My Theme';
    _backgroundColor = base.backgroundColor;
    _textColor = base.textColor;
    _headingColor = base.headingColor;
    _accentColor = base.accentColor;
    _linkColor = base.linkColor;
    _shaderEffect = base.shaderEffect;
    _shaderIntensity = base.shaderIntensity;
    _shaderSpeed = base.shaderSpeed;
    _vignetteIntensity = base.vignetteIntensity;
  }

  ReadingTheme get _currentTheme => ReadingTheme(
        id: widget.baseTheme?.id ??
            'custom-${DateTime.now().millisecondsSinceEpoch}',
        name: _name,
        backgroundColor: _backgroundColor,
        textColor: _textColor,
        headingColor: _headingColor,
        accentColor: _accentColor,
        linkColor: _linkColor,
        shaderEffect: _shaderEffect,
        shaderIntensity: _shaderIntensity,
        shaderSpeed: _shaderSpeed,
        vignetteIntensity: _vignetteIntensity,
      );

  void _save() {
    context.read<ThemeService>().saveCustomTheme(_currentTheme);
    Navigator.pop(context, _currentTheme);
  }

  @override
  Widget build(BuildContext context) {
    final theme = _currentTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0e0e16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Theme Editor',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live preview
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Stack(
              children: [
                Container(color: theme.backgroundColor),
                ShaderBackground(theme: theme, scrollOffset: 0),
                if (theme.vignetteIntensity > 0)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: RadialGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black
                                .withValues(alpha: theme.vignetteIntensity),
                          ],
                          radius: 1.2,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chapter Title',
                          style: TextStyle(
                              color: theme.headingColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'The quick brown fox jumps over the lazy dog. '
                        'This is sample body text to preview how your '
                        'reading experience will look.',
                        style: TextStyle(
                            color: theme.textColor,
                            fontSize: 15,
                            height: 1.6),
                      ),
                      const SizedBox(height: 4),
                      Text('A sample link',
                          style: TextStyle(
                              color: theme.linkColor,
                              decoration: TextDecoration.underline,
                              decorationColor:
                                  theme.linkColor.withValues(alpha: 0.4),
                              fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Editor controls
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // Theme name
                _SectionLabel('Name'),
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: _name),
                  onChanged: (v) => setState(() => _name = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 20),

                // Colors
                _SectionLabel('Colors'),
                const SizedBox(height: 12),
                _ColorRow(
                    label: 'Background',
                    color: _backgroundColor,
                    onChanged: (c) =>
                        setState(() => _backgroundColor = c)),
                _ColorRow(
                    label: 'Text',
                    color: _textColor,
                    onChanged: (c) => setState(() => _textColor = c)),
                _ColorRow(
                    label: 'Headings',
                    color: _headingColor,
                    onChanged: (c) =>
                        setState(() => _headingColor = c)),
                _ColorRow(
                    label: 'Accent',
                    color: _accentColor,
                    onChanged: (c) =>
                        setState(() => _accentColor = c)),
                _ColorRow(
                    label: 'Links',
                    color: _linkColor,
                    onChanged: (c) => setState(() => _linkColor = c)),
                const SizedBox(height: 20),

                // Shader effect
                _SectionLabel('Background Effect'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final effect in ShaderEffect.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _EffectChip(
                            label: _effectName(effect),
                            selected: _shaderEffect == effect,
                            onTap: () =>
                                setState(() => _shaderEffect = effect),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Color palettes for the selected effect
                if (_shaderEffect != ShaderEffect.none &&
                    ReadingTheme.palettes.containsKey(_shaderEffect)) ...[
                  _SectionLabel('Color Palettes'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final palette
                            in ReadingTheme.palettes[_shaderEffect]!)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _backgroundColor = palette.$2;
                                _textColor = palette.$3;
                                _headingColor = palette.$4;
                                _accentColor = palette.$5;
                                _linkColor = palette.$6;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: palette.$2,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      palette.$1,
                                      style: TextStyle(
                                        color: palette.$3,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    for (final c in [
                                      palette.$4,
                                      palette.$5,
                                      palette.$6
                                    ])
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin:
                                            const EdgeInsets.only(right: 3),
                                        decoration: BoxDecoration(
                                          color: c,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Shader intensity
                if (_shaderEffect != ShaderEffect.none) ...[
                  _SliderRow(
                    label: 'Effect Intensity',
                    value: _shaderIntensity,
                    min: 0.01,
                    max: 0.3,
                    onChanged: (v) =>
                        setState(() => _shaderIntensity = v),
                    displayValue:
                        '${(_shaderIntensity * 100).round()}%',
                  ),
                  _SliderRow(
                    label: 'Effect Speed',
                    value: _shaderSpeed,
                    min: 0.0,
                    max: 3.0,
                    onChanged: (v) =>
                        setState(() => _shaderSpeed = v),
                    displayValue: '${_shaderSpeed.toStringAsFixed(1)}x',
                  ),
                ],

                // Vignette
                _SliderRow(
                  label: 'Vignette',
                  value: _vignetteIntensity,
                  min: 0.0,
                  max: 0.5,
                  onChanged: (v) =>
                      setState(() => _vignetteIntensity = v),
                  displayValue:
                      '${(_vignetteIntensity * 100).round()}%',
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _effectName(ShaderEffect effect) {
    switch (effect) {
      case ShaderEffect.none:
        return 'None';
      case ShaderEffect.holographic:
        return 'Holographic';
      case ShaderEffect.aurora:
        return 'Aurora';
      case ShaderEffect.opalescent:
        return 'Opalescent';
      case ShaderEffect.prismatic:
        return 'Prismatic';
      case ShaderEffect.ember:
        return 'Ember';
      case ShaderEffect.mandelbrot:
        return 'Mandelbrot';
      case ShaderEffect.julia:
        return 'Julia Set';
      case ShaderEffect.oilSlick:
        return 'Oil Slick';
      case ShaderEffect.voronoi:
        return 'Voronoi';
      case ShaderEffect.plasma:
        return 'Plasma';
    }
  }
}

// ── Color picker (simple HSL-based) ──

class _ColorRow extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  const _ColorRow({
    required this.label,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _showColorPicker(context),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const Spacer(),
            Text(
              '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit, size: 16, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _HSLColorPicker(
        initialColor: color,
        onChanged: onChanged,
      ),
    );
  }
}

class _HSLColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onChanged;

  const _HSLColorPicker({
    required this.initialColor,
    required this.onChanged,
  });

  @override
  State<_HSLColorPicker> createState() => _HSLColorPickerState();
}

class _HSLColorPickerState extends State<_HSLColorPicker> {
  late double _hue;
  late double _saturation;
  late double _lightness;

  @override
  void initState() {
    super.initState();
    final hsl = HSLColor.fromColor(widget.initialColor);
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    _lightness = hsl.lightness;
  }

  Color get _color =>
      HSLColor.fromAHSL(1.0, _hue, _saturation, _lightness).toColor();

  void _update() {
    widget.onChanged(_color);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color preview
            Container(
              width: double.infinity,
              height: 48,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
            ),

            // Hue
            _pickerSlider('Hue', _hue, 0, 360, (v) {
              setState(() => _hue = v);
              _update();
            }, gradient: _hueGradient()),

            // Saturation
            _pickerSlider('Saturation', _saturation, 0, 1, (v) {
              setState(() => _saturation = v);
              _update();
            }),

            // Lightness
            _pickerSlider('Lightness', _lightness, 0, 1, (v) {
              setState(() => _lightness = v);
              _update();
            }),

            const SizedBox(height: 8),

            // Preset quick colors
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _presetColors)
                  GestureDetector(
                    onTap: () {
                      final hsl = HSLColor.fromColor(c);
                      setState(() {
                        _hue = hsl.hue;
                        _saturation = hsl.saturation;
                        _lightness = hsl.lightness;
                      });
                      _update();
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged,
      {Gradient? gradient}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
              width: 72,
              child: Text(label,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12))),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 8,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: Colors.white38,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _hueGradient() {
    return LinearGradient(
      colors: [
        for (var i = 0; i <= 360; i += 60)
          HSLColor.fromAHSL(1, i.toDouble(), 1, 0.5).toColor(),
      ],
    );
  }

  static const _presetColors = [
    Color(0xFF000000),
    Color(0xFF1a1a2e),
    Color(0xFF0a0a14),
    Color(0xFF0d1117),
    Color(0xFF1e1e1e),
    Color(0xFF2d2d2d),
    Color(0xFFffffff),
    Color(0xFFFAF5EB),
    Color(0xFFe0dfe8),
    Color(0xFFc9d1d9),
    Color(0xFF7c6fef),
    Color(0xFF58a6ff),
    Color(0xFF7ee8be),
    Color(0xFFf0a868),
    Color(0xFFd47030),
    Color(0xFFe8d5c4),
    Color(0xFFff6b6b),
    Color(0xFFffd93d),
    Color(0xFF6bcb77),
    Color(0xFF4d96ff),
  ];
}

// ── Shared widgets ──

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String displayValue;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.displayValue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              activeColor: Colors.white54,
              inactiveColor: Colors.white12,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              displayValue,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _EffectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _EffectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.white30 : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white38,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
