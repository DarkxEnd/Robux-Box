import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Coins flying from a point toward the balance in the header.
///
/// Purely decorative and driven by a single AnimationController, so it never
/// touches state — the balance itself has already been updated by the server
/// before this plays.
class CoinParticles extends StatefulWidget {
  const CoinParticles({
    super.key,
    required this.child,
    required this.play,
    this.count = 14,
  });

  final Widget child;
  final bool play;
  final int count;

  @override
  State<CoinParticles> createState() => _CoinParticlesState();
}

class _CoinParticlesState extends State<CoinParticles>
    with SingleTickerProviderStateMixin {
  final _rand = Random();

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late List<double> _angles = _makeAngles();

  List<double> _makeAngles() =>
      List.generate(widget.count, (_) => _rand.nextDouble() * pi * 2);

  @override
  void didUpdateWidget(CoinParticles old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play) {
      _angles = _makeAngles();
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        widget.child,
        if (_c.isAnimating || _c.value > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) =>
                    CustomPaint(painter: _CoinPainter(_angles, _c.value)),
              ),
            ),
          ),
      ],
    );
  }
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter(this.angles, this.t);

  final List<double> angles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0) return;
    final centre = size.center(Offset.zero);
    final spread = size.shortestSide * 0.75 * Curves.easeOut.transform(t);
    final paint = Paint()..color = AppTheme.coin.withValues(alpha: 1 - t);

    for (final a in angles) {
      canvas.drawCircle(
        centre + Offset(cos(a), sin(a)) * spread,
        5 * (1 - t * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CoinPainter old) => old.t != t;
}
