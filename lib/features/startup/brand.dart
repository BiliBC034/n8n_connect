import 'dart:math' as math;

import 'package:flutter/material.dart';

/// n8n Connect logo: "c8c" in white strokes on a rounded square with a pink
/// gradient. Drawn with [CustomPainter] from the geometry of
/// `assets/branding/logo.svg` (viewBox 512), scaled to [size].
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'n8n Connect',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: const _BrandMarkPainter(),
      ),
    );
  }
}

/// Paints the logo on a 512×512 logical canvas and scales it to the real size.
class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter();

  /// Side of the logical canvas the logo is designed on.
  static const double _design = 512;

  /// Corner radius of the background square.
  static const double _cornerRadius = 112;

  /// Width of the white strokes.
  static const double _strokeWidth = 30;

  /// Radius of each circle and arc.
  static const double _radius = 44;

  static const Color _gradientStart = Color(0xFFFF7A93);
  static const Color _gradientEnd = Color(0xFFD9365F);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _design;
    canvas.save();
    canvas.scale(scale);

    // Background: rounded square with a gradient from top-left to
    // bottom-right.
    const bounds = Rect.fromLTWH(0, 0, _design, _design);
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_gradientStart, _gradientEnd],
      ).createShader(bounds);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(_cornerRadius)),
      background,
    );

    // White strokes with round ends (the "c" and the "8").
    final stroke = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // The "c" shapes are 250° arcs open to the right, from -55° to +55°.
    const arcStart = 55 * math.pi / 180;
    const arcSweep = 250 * math.pi / 180;
    final leftC = Path()
      ..addArc(
        Rect.fromCircle(center: const Offset(140, 256), radius: _radius),
        arcStart,
        arcSweep,
      );
    final rightC = Path()
      ..addArc(
        Rect.fromCircle(center: const Offset(390, 256), radius: _radius),
        arcStart,
        arcSweep,
      );
    canvas.drawPath(leftC, stroke);
    canvas.drawPath(rightC, stroke);

    // The "8" is two stacked circles.
    canvas.drawCircle(const Offset(260, 212), _radius, stroke);
    canvas.drawCircle(const Offset(260, 300), _radius, stroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) => false;
}
