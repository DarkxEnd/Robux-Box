import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_theme.dart';

/// A small coloured label — redemption status, VIP tier, offer state.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  /// Maps a redemption status string to its conventional colour. Kept here so
  /// the same status is never green on one screen and grey on another.
  factory StatusPill.forStatus(String status) {
    final (color, icon) = switch (status) {
      'completed' => (AppTheme.success, Icons.check_circle_outline),
      'processing' => (AppTheme.accent, Icons.sync),
      'pending' => (AppTheme.warning, Icons.schedule),
      'rejected' => (AppTheme.danger, Icons.cancel_outlined),
      'cancelled' => (Colors.grey, Icons.remove_circle_outline),
      _ => (Colors.grey, Icons.help_outline),
    };
    return StatusPill(
      label: status[0].toUpperCase() + status.substring(1),
      color: color,
      icon: icon,
    );
  }

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 1 : 0.14),
        borderRadius: AppDimens.brPill,
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: filled ? Colors.white : color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: filled ? Colors.white : color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
