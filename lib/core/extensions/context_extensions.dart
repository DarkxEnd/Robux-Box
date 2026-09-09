import 'package:flutter/material.dart';

/// Shorthands for the things every screen reaches for.
extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  MediaQueryData get media => MediaQuery.of(this);
  Size get screenSize => MediaQuery.sizeOf(this);
  EdgeInsets get safePadding => MediaQuery.paddingOf(this);

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// True for the narrow layout. The breakpoint is deliberately low — this is
  /// a phone app, and the only "wide" case worth handling is a tablet or the
  /// web preview build.
  bool get isCompact => MediaQuery.sizeOf(this).width < 600;

  /// The app ships in Arabic, so direction-aware padding and alignment are not
  /// optional. Anything that hard-codes `left`/`right` will look wrong here.
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;

  void pop<T>([T? result]) => Navigator.of(this).pop(result);

  /// Dismisses the keyboard without needing a FocusNode.
  void unfocus() => FocusScope.of(this).unfocus();
}
