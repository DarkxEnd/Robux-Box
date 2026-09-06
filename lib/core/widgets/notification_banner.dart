import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import 'glass_card.dart';

/// An in-page prompt — "turn on notifications", "verify your email".
///
/// Dismissible by design: a banner the user cannot get rid of is worse than no
/// banner, and Android 13 only allows one notification permission prompt, so
/// nagging costs the permission permanently.
class NotificationBanner extends StatelessWidget {
  const NotificationBanner({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    this.onDismiss,
    this.icon = Icons.notifications_active_outlined,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onDismiss;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
      child: GlassCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(body, style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppDimens.sm),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: onAction,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.lg,
                          ),
                        ),
                        child: Text(actionLabel),
                      ),
                      if (onDismiss != null)
                        TextButton(
                          onPressed: onDismiss,
                          child: const Text('Not now'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
