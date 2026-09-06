import 'package:flutter/material.dart';

/// Google's four-colour "G", drawn rather than bundled.
///
/// Google's branding guidelines require the mark to be reproduced exactly, and
/// drawing it keeps it sharp at any size without shipping four PNG densities.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.22;
    final arc = rect.deflate(stroke / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Four quadrants, starting at the right and going clockwise.
    canvas
      ..drawArc(arc, -0.55, -1.02, false, paint..color = _red)
      ..drawArc(arc, -1.57, -1.57, false, paint..color = _yellow)
      ..drawArc(arc, 3.14, -1.57, false, paint..color = _green)
      ..drawArc(arc, 1.57, -1.05, false, paint..color = _blue);

    // The horizontal bar of the G.
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.5,
        size.height * 0.42,
        size.width * 0.5,
        stroke,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}
