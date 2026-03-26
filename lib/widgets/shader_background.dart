import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/reading_theme.dart';

/// A widget that renders the holographic/aurora/etc. shader effect
/// as a background layer behind the reading content.
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
  late AnimationController _controller;
  bool _shaderFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
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
        // Start a slow continuous animation
        _controller.animateWith(
          _LinearSimulation(speed: widget.theme.shaderSpeed),
        );
      }
    } catch (e) {
      debugPrint('Shader load failed: $e');
      if (mounted) setState(() => _shaderFailed = true);
    }
  }

  @override
  void didUpdateWidget(ShaderBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme.shaderSpeed != widget.theme.shaderSpeed) {
      _controller.animateWith(
        _LinearSimulation(speed: widget.theme.shaderSpeed),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shaderFailed ||
        _shader == null ||
        widget.theme.shaderEffect == ShaderEffect.none) {
      return const SizedBox.expand();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ShaderPainter(
            shader: _shader!,
            time: _controller.value,
            intensity: widget.theme.shaderIntensity,
            scrollY: widget.scrollOffset,
            mode: widget.theme.shaderModeValue,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final double intensity;
  final double scrollY;
  final double mode;

  _ShaderPainter({
    required this.shader,
    required this.time,
    required this.intensity,
    required this.scrollY,
    required this.mode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Set uniforms: uSize (vec2), uTime, uIntensity, uScrollY, uMode
    shader.setFloat(0, size.width);   // uSize.x
    shader.setFloat(1, size.height);  // uSize.y
    shader.setFloat(2, time);         // uTime
    shader.setFloat(3, intensity);    // uIntensity
    shader.setFloat(4, scrollY);      // uScrollY
    shader.setFloat(5, mode);         // uMode

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_ShaderPainter oldDelegate) => true;
}

/// A simple simulation that increases linearly forever.
/// Used to drive the shader time uniform.
class _LinearSimulation extends Simulation {
  final double speed;

  _LinearSimulation({this.speed = 1.0});

  @override
  double x(double time) => time * speed;

  @override
  double dx(double time) => speed;

  @override
  bool isDone(double time) => false;

}
