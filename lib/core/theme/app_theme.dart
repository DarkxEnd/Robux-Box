import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_dimens.dart';
import 'app_typography.dart';

/// The app's two themes.
///
/// Dark is the primary design — the app is used mostly in the evening and the
/// gradient/glass treatment reads far better on a dark ground. Light is a
/// faithful equivalent rather than an afterthought, because Android's
/// system-wide light mode is still the default on most devices.
abstract final class AppTheme {
  const AppTheme._();

  // Brand palette.
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryBright = Color(0xFF8B7BFF);
  static const Color accent = Color(0xFF00D1FF);
  static const Color coin = Color(0xFFFFC94A);
  static const Color success = Color(0xFF2FD07A);
  static const Color warning = Color(0xFFFFA726);
  static const Color danger = Color(0xFFFF5A5F);

  static const Color _darkBg = Color(0xFF0C0E14);
  static const Color _darkSurface = Color(0xFF161923);
  static const Color _lightBg = Color(0xFFF6F7FB);

  static ThemeData get dark => _build(
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: primaryBright,
          secondary: accent,
          tertiary: coin,
          surface: _darkSurface,
          error: danger,
        ),
        scaffoldBackground: _darkBg,
        textTheme: AppTypography.dark,
      );

  static ThemeData get light => _build(
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          secondary: const Color(0xFF0094B3),
          tertiary: const Color(0xFFB07E00),
          surface: Colors.white,
          error: danger,
        ),
        scaffoldBackground: _lightBg,
        textTheme: AppTypography.light,
      );

  static ThemeData _build(
    ColorScheme scheme, {
    required Color scaffoldBackground,
    required TextTheme Function(TextTheme) textTheme,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme(base.textTheme),
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: scheme.onSurface,
        // Set explicitly: with a transparent app bar Android otherwise picks
        // icon colours from the *system* theme, which can invert them against
        // an in-app theme the user chose manually.
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: scaffoldBackground,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: scaffoldBackground,
              ),
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppDimens.brLg),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
          shape: const RoundedRectangleBorder(borderRadius: AppDimens.brMd),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
          shape: const RoundedRectangleBorder(borderRadius: AppDimens.brMd),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // Text buttons default to a 36pt target, below the accessibility
          // minimum.
          minimumSize: const Size(AppDimens.minTouchTarget, AppDimens.minTouchTarget),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.035),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.lg,
          vertical: AppDimens.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: AppDimens.brMd,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimens.brMd,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimens.brMd,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimens.brMd,
          borderSide: BorderSide(color: scheme.error),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusXl),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppDimens.brLg),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF232734) : const Color(0xFF2A2D36),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: AppDimens.brMd),
      ),

      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppDimens.brPill),
        side: BorderSide(color: scheme.outlineVariant),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outlineVariant.withValues(alpha: 0.4),
      ),

      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppDimens.brMd),
      ),
    );
  }

  /// Gradient used by the primary CTA and the balance card.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coinGradient = LinearGradient(
    colors: [Color(0xFFFFD86B), Color(0xFFFFA726)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
