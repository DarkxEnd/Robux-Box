import 'package:flutter/material.dart';

import '../error/failure.dart';
import '../theme/app_dimens.dart';
import '../theme/app_theme.dart';

/// Transient feedback.
///
/// Always clears any toast already showing first: two stacked snackbars queue
/// up, so a burst of actions would leave the last message on screen long after
/// the user moved on.
abstract final class AppToast {
  const AppToast._();

  static void success(BuildContext context, String message) =>
      _show(context, message, AppTheme.success, Icons.check_circle_outline);

  static void error(BuildContext context, String message) =>
      _show(context, message, AppTheme.danger, Icons.error_outline);

  static void info(BuildContext context, String message) =>
      _show(context, message, AppTheme.accent, Icons.info_outline);

  /// Renders a [Failure] with the icon its type deserves.
  static void failure(BuildContext context, Failure failure) => _show(
    context,
    failure.message,
    switch (failure) {
      NetworkFailure() => AppTheme.warning,
      _ => AppTheme.danger,
    },
    switch (failure) {
      NetworkFailure() => Icons.wifi_off_rounded,
      AuthFailure() => Icons.lock_outline,
      PermissionFailure() => Icons.block_outlined,
      _ => Icons.error_outline,
    },
  );

  static void _show(
    BuildContext context,
    String message,
    Color accent,
    IconData icon,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: AppDimens.md),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
