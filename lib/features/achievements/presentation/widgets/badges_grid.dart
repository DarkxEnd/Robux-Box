import 'package:flutter/material.dart';

import '../../../../core/extensions/format_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../models/achievement.dart';

/// The achievement grid.
class BadgesGrid extends StatelessWidget {
  const BadgesGrid({super.key, required this.items, required this.onTap});

  final List<AchievementView> items;
  final void Function(AchievementView) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppDimens.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppDimens.md,
        mainAxisSpacing: AppDimens.md,
        childAspectRatio: 0.95,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _Badge(view: items[i], onTap: () => onTap(items[i])),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.view, required this.onTap});

  final AchievementView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = view.isUnlocked;
    final claimable = view.isClaimable;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppDimens.brLg,
          border: Border.all(
            color: claimable
                ? AppTheme.coin
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: claimable ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: unlocked ? AppTheme.coinGradient : null,
                color: unlocked
                    ? null
                    : theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                unlocked ? Icons.military_tech : Icons.lock_outline,
                color: unlocked
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
                size: 27,
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            Text(
              view.achievement.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppDimens.xs),
            if (!unlocked) ...[
              ClipRRect(
                borderRadius: AppDimens.brPill,
                child: LinearProgressIndicator(
                  value: view.progressFraction,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                // Shows how far along rather than just "locked" — a bare lock
                // gives the user nothing to aim at.
                '${(view.state?.progress ?? 0).compact}'
                ' / ${view.achievement.threshold.compact}',
                style: theme.textTheme.labelSmall,
              ),
            ] else
              Text(
                claimable
                    ? '+${view.achievement.rewardCoins.compact}'
                    : '✓',
                style: TextStyle(
                  color: claimable ? AppTheme.coin : AppTheme.success,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
