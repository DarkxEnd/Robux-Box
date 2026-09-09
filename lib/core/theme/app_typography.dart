import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The type scale.
///
/// Uses Google Fonts' *bundled-at-runtime* fetch, so the first launch on a
/// cold cache falls back to the platform font for a frame. That is accepted:
/// bundling eight weights of two families would add several megabytes to a
/// download that competes with much lighter apps.
abstract final class AppTypography {
  const AppTypography._();

  /// Display face — used for balances and headline numbers only.
  static TextTheme _base(TextTheme base, Color color) {
    final body = GoogleFonts.interTextTheme(base);
    return body
        .copyWith(
          displayLarge: GoogleFonts.outfit(
            textStyle: base.displayLarge,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
          displayMedium: GoogleFonts.outfit(
            textStyle: base.displayMedium,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
          displaySmall: GoogleFonts.outfit(
            textStyle: base.displaySmall,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          headlineMedium: GoogleFonts.outfit(
            textStyle: base.headlineMedium,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: GoogleFonts.outfit(
            textStyle: base.headlineSmall,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: GoogleFonts.outfit(
            textStyle: base.titleLarge,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(bodyColor: color, displayColor: color);
  }

  static TextTheme light(TextTheme base) =>
      _base(base, const Color(0xFF14161C));
  static TextTheme dark(TextTheme base) => _base(base, const Color(0xFFF4F6FB));

  /// Tabular figures for anything that ticks — a counter that reflows on every
  /// digit change is visually noisy.
  static const TextStyle tabular = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
