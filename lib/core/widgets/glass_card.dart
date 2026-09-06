import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';

/// A translucent, blurred panel — the app's default container.
///
/// The blur is genuinely expensive on low-end Android, which is most of this
/// app's install base, so [blur] can be turned off for anything that appears
/// inside a scrolling list. Only use it on a handful of hero surfaces.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = AppDimens.cardPadding,
    this.borderRadius = AppDimens.brLg,
    this.blur = false,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final bool blur;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null
            ? (isDark
                  ? Colors.white.withValues(alpha: 0.055)
                  : Colors.white.withValues(alpha: 0.85))
            : null,
        borderRadius: borderRadius,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.09)
              : scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: child,
    );

    if (blur) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: content,
        ),
      );
    }

    if (onTap == null) return content;
    return InkWell(onTap: onTap, borderRadius: borderRadius, child: content);
  }
}
