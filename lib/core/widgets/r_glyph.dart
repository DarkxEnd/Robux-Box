import 'package:flutter/material.dart';

/// The app mark: a rounded square with the Robux "R".
///
/// Drawn rather than shipped as an image so it stays crisp at every size and
/// picks up the current theme, and so the splash screen needs no asset decode
/// before its first frame.
class RGlyph extends StatelessWidget {
  const RGlyph({super.key, this.size = 48, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Colors.white;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(
            color: fg.withValues(alpha: 0.35),
            width: size * 0.03,
          ),
        ),
        child: Center(
          child: Text(
            'R',
            style: TextStyle(
              fontSize: size * 0.52,
              fontWeight: FontWeight.w900,
              color: fg,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
