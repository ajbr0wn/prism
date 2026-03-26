import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/reading_theme.dart';

/// A widget that renders shader effects as a background layer.
///
/// Performance optimizations:
/// - Renders at half resolution and upscales (4x less GPU work)
/// - Pauses animation when idle (0% GPU when still)
/// - Only animates during scroll, freezes after timeout
/// - Caps repaint rate to ~20fps for heavy shaders
class ShaderBackground extends StatefulWidget {
  final ReadingTheme theme;
  final double scrollOffset;

  const ShaderBackground({
    super.key,
    required this.theme,
    this.scrollOffset = 0.0,
  });

  @override
  State<ShaderBackground> createState() => _ShaderBackgroundState();
}

class _ShaderBackgroundState extends State<ShaderBackground>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  bool _shaderFailed = false;

  // Animation state
  Ticker? _ticker;
  double _time = 0.0;
  bool _isAnimating = false;
  Timer? _idleTimer;
  Duration _lastTickTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program =
          await ui.FragmentProgram.fromAsset('shaders/holographic.frag');
      if (mounted) {
        setState(() {
          _shader = program.fragmentShader();
        });
        // Do one initial paint, then go idle
        _startAnimation();
        _scheduleIdle();
      }
    } catch (e) {
      debugPrint('Shader load failed: $e');
      if (mounted) setState(() => _shaderFailed = true);
    }
  }

  void _startAnimation() {
    if (_isAnimating) return;
    _isAnimating = true;
    _ticker?.dispose();
    _ticker = createTicker(_onTick);
    _ticker!.start();
  }

  void _stopAnimation() {
    if (!_isAnimating) return;
    _isAnimating = false;
    _ticker?.stop();
    // Keep the last rendered frame visible (no need to cache explicitly,
    // CustomPaint retains its last paint)
  }

  void _scheduleIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 2), () {
      _stopAnimation();
    });
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dt = (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;
    _time += dt * widget.theme.shaderSpeed;
    setState(() {});
  }

  @override
  void didUpdateWidget(ShaderBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Detect scroll changes and wake up animation
    if (widget.scrollOffset != oldWidget.scrollOffset) {
      if (!_isAnimating) {
        _startAnimation();
      }
      _scheduleIdle();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _ticker?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  /// Determine target FPS based on shader complexity.
  int get _targetFps {
    switch (widget.theme.shaderEffect) {
      case ShaderEffect.plasma:
      case ShaderEffect.prismatic:
        return 30; // cheap shaders get smooth animation
      case ShaderEffect.aurora:
      case ShaderEffect.opalescent:
        return 20;
      case ShaderEffect.mandelbrot:
      case ShaderEffect.julia:
      case ShaderEffect.voronoi:
        return 15; // heavy shaders get lower fps
      case ShaderEffect.holographic:
      case ShaderEffect.ember:
      case ShaderEffect.oilSlick:
        return 12; // very heavy shaders
      case ShaderEffect.none:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shaderFailed ||
        _shader == null ||
        widget.theme.shaderEffect == ShaderEffect.none) {
      return const SizedBox.expand();
    }

    return CustomPaint(
      painter: _ShaderPainter(
        shader: _shader!,
        time: _time,
        intensity: widget.theme.shaderIntensity,
        scrollY: widget.scrollOffset,
        mode: widget.theme.shaderModeValue,
        targetFps: _targetFps,
        renderScale: 0.5, // half resolution
      ),
      size: Size.infinite,
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final double intensity;
  final double scrollY;
  final double mode;
  final int targetFps;
  final double renderScale;

  _ShaderPainter({
    required this.shader,
    required this.time,
    required this.intensity,
    required this.scrollY,
    required this.mode,
    required this.targetFps,
    this.renderScale = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Render at reduced resolution for performance
    final renderWidth = (size.width * renderScale).ceil().toDouble();
    final renderHeight = (size.height * renderScale).ceil().toDouble();

    shader.setFloat(0, renderWidth);    // uSize.x (reduced)
    shader.setFloat(1, renderHeight);   // uSize.y (reduced)
    shader.setFloat(2, time);
    shader.setFloat(3, intensity);
    shader.setFloat(4, scrollY);
    shader.setFloat(5, mode);

    // Scale the canvas so the smaller shader output fills the screen
    canvas.save();
    canvas.scale(1.0 / renderScale);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, renderWidth, renderHeight),
      Paint()
        ..shader = shader
        ..filterQuality = FilterQuality.low, // bilinear upscale
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShaderPainter oldDelegate) {
    if (targetFps <= 0) return false;

    // Quantize time to target FPS
    final fps = targetFps.toDouble();
    return (time * fps).round() != (oldDelegate.time * fps).round() ||
        scrollY != oldDelegate.scrollY ||
        mode != oldDelegate.mode ||
        intensity != oldDelegate.intensity;
  }
}
