import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A branded spinner for full-screen waits (loading an ad, opening a wall).
///
/// A plain CircularProgressIndicator is fine inside a button; on a blocking
/// overlay it reads as the app having hung, so this one keeps moving visibly.
class PremiumLoader extends StatefulWidget {
  const PremiumLoader({super.key, this.size = 56, this.message});

  final double size;
  final String? message;

  @override
  State<PremiumLoader> createState() => _PremiumLoaderState();
}

class _PremiumLoaderState extends State<PremiumLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: RotationTransition(
            turns: _c,
            child: CustomPaint(painter: _ArcPainter()),
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.message!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(3),
      0,
      4.2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..shader = AppTheme.brandGradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => false;
}

/// Blocks the screen while an action runs. Dismissed by popping the route.
Future<T?> showBlockingLoader<T>(BuildContext context, {String? message}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => PopScope(
      // The action behind this is usually a server call that cannot be
      // cancelled; letting back dismiss it would leave the user on a screen
      // whose state is about to change under them.
      canPop: false,
      child: Center(child: PremiumLoader(message: message)),
    ),
  );
}
