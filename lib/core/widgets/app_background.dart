import 'package:flutter/material.dart';

/// The ambient background: two soft radial glows behind the content.
///
/// Painted with a CustomPainter rather than stacked blurred Containers so it
/// costs one draw call instead of two full-screen blur passes — this sits
/// behind every screen, so it has to be close to free.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.intensity = 1});

  final Widget child;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _GlowPainter(
              primary: scheme.primary,
              secondary: scheme.secondary,
              intensity: intensity,
              dark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({
    required this.primary,
    required this.secondary,
    required this.intensity,
    required this.dark,
  });

  final Color primary;
  final Color secondary;
  final double intensity;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = (dark ? 0.20 : 0.12) * intensity;

    void glow(Offset center, double radius, Color color) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    glow(
      Offset(size.width * 0.15, size.height * 0.08),
      size.width * 0.7,
      primary,
    );
    glow(
      Offset(size.width * 0.9, size.height * 0.35),
      size.width * 0.6,
      secondary,
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.primary != primary ||
      old.secondary != secondary ||
      old.intensity != intensity ||
      old.dark != dark;
}
