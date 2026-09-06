import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

/// The prize wheel.
///
/// The wheel does not decide anything. `playDailyGame` returns the winning
/// index and this animates *onto* it — a client-side random spin would either
/// disagree with the coins actually credited or be trivially riggable.
class SpinWheel extends StatelessWidget {
  const SpinWheel({
    super.key,
    required this.rotation,
    this.size = 260,
    this.prizes = AppConstants.spinWheelPrizes,
  });

  /// Turns, not radians — feeds an AnimationController driven by the caller.
  final double rotation;
  final double size;
  final List<int> prizes;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: rotation * 2 * pi,
            child: CustomPaint(
              size: Size.square(size),
              painter: _WheelPainter(prizes),
            ),
          ),
          // Hub, drawn over the segments so the seams are hidden.
          Container(
            width: size * 0.22,
            height: size * 0.22,
            decoration: const BoxDecoration(
              gradient: AppTheme.brandGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_rounded, color: Colors.white),
          ),
          // Pointer at the top, outside the rotating subtree so it stays put.
          Positioned(
            top: 0,
            child: CustomPaint(
              size: const Size(22, 26),
              painter: _PointerPainter(),
            ),
          ),
        ],
      ),
    );
  }

  /// The rotation that lands [index] under the pointer.
  ///
  /// [extraTurns] adds full revolutions so the spin reads as a spin rather
  /// than a jump.
  static double rotationFor(int index, int segments, {int extraTurns = 6}) {
    final step = 1 / segments;
    // Half a segment so the pointer sits mid-slice, not on a boundary.
    return extraTurns + (1 - (index * step) - step / 2);
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter(this.prizes);

  final List<int> prizes;

  static const _colors = [
    AppTheme.primary,
    AppTheme.accent,
    AppTheme.success,
    AppTheme.warning,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = size.width / 2;
    final sweep = 2 * pi / prizes.length;

    for (var i = 0; i < prizes.length; i++) {
      final start = -pi / 2 + i * sweep;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = _colors[i % _colors.length],
      );

      // Prize label, rotated to sit along the slice.
      final painter = TextPainter(
        text: TextSpan(
          text: '${prizes[i]}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final angle = start + sweep / 2;
      final pos = centre + Offset(cos(angle), sin(angle)) * (radius * 0.68);

      canvas
        ..save()
        ..translate(pos.dx, pos.dy)
        ..rotate(angle + pi / 2);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }

    canvas.drawCircle(
      centre,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.prizes != prizes;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = AppTheme.coin);
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) => false;
}
