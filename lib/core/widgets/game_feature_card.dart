import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import 'pressable.dart';

/// A large tappable tile for an earning method (watch an ad, spin, offers).
///
/// [locked] renders the disabled state with its reason visible, rather than
/// hiding the tile: a card that vanishes when the daily cap is reached looks
/// like a bug, while one that says "come back tomorrow" brings the user back.
class GameFeatureCard extends StatelessWidget {
  const GameFeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.onTap,
    this.locked = false,
    this.lockedReason,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback? onTap;
  final bool locked;
  final String? lockedReason;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Pressable(
      enabled: !locked,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.lg),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: AppDimens.brLg,
          boxShadow: locked
              ? null
              : [
                  BoxShadow(
                    color: gradient.colors.first.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: AppDimens.brMd,
              ),
              child: Icon(
                locked ? Icons.lock_outline : icon,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppDimens.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locked ? (lockedReason ?? subtitle) : subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
