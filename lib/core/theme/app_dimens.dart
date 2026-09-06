import 'package:flutter/widgets.dart';

/// Spacing, radii and durations on a fixed scale.
///
/// A scale rather than ad-hoc numbers: every gap in the app is one of these,
/// which is what keeps 40-odd screens looking like one product.
abstract final class AppDimens {
  const AppDimens._();

  // 4pt spacing scale.
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // Corner radii.
  static const double radiusSm = 8;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radiusPill = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius brPill = BorderRadius.all(
    Radius.circular(radiusPill),
  );

  /// Google's minimum touch target. Anything tappable must reach this, or the
  /// accessibility scanner in Play Console flags the build.
  static const double minTouchTarget = 48;

  static const double buttonHeight = 52;
  static const double inputHeight = 56;
  static const double navBarHeight = 68;
  static const double appBarHeight = 56;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);

  /// Bottom padding that clears the nav bar so the last list item is never
  /// hidden behind it.
  static const EdgeInsets listBottomPadding = EdgeInsets.only(
    bottom: navBarHeight + xl,
  );

  // Motion. Kept short — this app is used in 20-second bursts and slow
  // transitions read as lag.
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration celebration = Duration(milliseconds: 1200);
}
