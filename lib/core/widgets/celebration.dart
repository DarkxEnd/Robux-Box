import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A burst of confetti over the whole screen.
///
/// Self-removing: it inserts an overlay entry and takes it down when the
/// animation ends, so a caller cannot leak it by navigating away mid-burst.
abstract final class Celebration {
  const Celebration._();

  static void burst(BuildContext context) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ConfettiLayer(onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }
}

class _ConfettiLayer extends StatefulWidget {
  const _ConfettiLayer({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer>
    with SingleTickerProviderStateMixin {
  static const _count = 40;
  final _rand = Random();
  late final List<_Piece> _pieces;

  late final AnimationController _c =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      });

  @override
  void initState() {
    super.initState();
    const palette = [
      AppTheme.coin,
      AppTheme.accent,
      AppTheme.primaryBright,
      AppTheme.success,
    ];
    _pieces = List.generate(
      _count,
      (i) => _Piece(
        x: _rand.nextDouble(),
        delay: _rand.nextDouble() * 0.25,
        drift: (_rand.nextDouble() - 0.5) * 0.35,
        size: 6 + _rand.nextDouble() * 7,
        spin: (_rand.nextDouble() - 0.5) * 8,
        color: palette[i % palette.length],
      ),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Must not swallow taps — the dialog underneath stays interactive.
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _c.value),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.drift,
    required this.size,
    required this.spin,
    required this.color,
  });

  final double x;
  final double delay;
  final double drift;
  final double size;
  final double spin;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      // Fall accelerates, and each piece fades out over the last third so the
      // burst ends softly instead of vanishing.
      final y = size.height * (local * local * 1.15) - p.size;
      final x = size.width * (p.x + p.drift * local);
      final opacity = local < 0.7 ? 1.0 : 1 - ((local - 0.7) / 0.3);

      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * local);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.55,
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = p.color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
