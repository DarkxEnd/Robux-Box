import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/pressable.dart';

/// A white, full-width provider button.
///
/// Deliberately plain rather than gradient-styled: Google's branding
/// guidelines require their button to keep a light background and their exact
/// mark, and a restyled one is a common cause of review rejections.
class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.background,
    this.foreground,
  });

  final String label;
  final Widget icon;
  final Future<void> Function()? onPressed;
  final bool busy;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = background ?? Colors.white;
    final fg = foreground ?? const Color(0xFF1F1F1F);

    return Pressable(
      enabled: !busy && onPressed != null,
      onTap: onPressed == null ? null : () => onPressed!(),
      child: Container(
        height: AppDimens.buttonHeight,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppDimens.brMd,
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: busy
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(width: AppDimens.md),
                    Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        fontSize: 15.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
