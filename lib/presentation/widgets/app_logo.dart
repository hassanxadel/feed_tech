import 'package:flutter/material.dart';

import 'package:feedtech/shared/constants/app_theme.dart';

/// App logo: a green tile with a white ear of grain, drawn in code (same design as
/// tool/make_icons.py) so no image has to be downloaded or decoded.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'فيد تك',
        child: CustomPaint(size: Size.square(size), painter: _LogoPainter()),
      );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.22)), Paint()..color = C.green);
    final white = Paint()..color = Colors.white;
    final h = s * 0.66, cx = s / 2, cy = s / 2;
    canvas.drawLine(Offset(cx, cy + h * 0.5), Offset(cx, cy - h * 0.32), white..strokeWidth = h * 0.07);
    for (final dy in [0.22, 0.0, -0.22]) {
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(cx + side * h * 0.13, cy + dy * h - h * 0.05);
        canvas.rotate(side * 0.61); // ~35° away from the stem
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: h * 0.16, height: h * 0.27), white);
        canvas.restore();
      }
    }
    canvas.drawOval(Rect.fromLTWH(cx - h * 0.08, cy - h * 0.5, h * 0.16, h * 0.27), white);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => false;
}
