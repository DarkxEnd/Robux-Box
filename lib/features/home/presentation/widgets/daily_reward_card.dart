import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/celebration.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../models/app_user.dart';
import '../../../earn/domain/earn_controller.dart';

/// The daily-streak claim, with the seven-day reward ladder.
class DailyRewardCard extends ConsumerWidget {
  const DailyRewardCard({super.key, required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final streak = user?.dailyStreak ?? 0;
    final canClaim = user?.canClaimDailyReward ?? false;

    // The ladder is 7 long and then repeats, so day 8 shows as position 1
    // again rather than running off the end of the row.
    final todayIndex = streak % AppConstants.dailyStreakRewards.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department,
                    color: AppTheme.warning),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: Text(
                    l.homeDailyReward,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  l.homeStreakDay(streak),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppDimens.lg),
            Row(
              children: [
                for (var i = 0;
                    i < AppConstants.dailyStreakRewards.length;
                    i++) ...[
                  Expanded(
                    child: _Day(
                      coins: AppConstants.dailyStreakRewards[i],
                      day: i + 1,
                      isToday: i == todayIndex,
                      isPast: i < todayIndex,
                    ),
                  ),
                  if (i < AppConstants.dailyStreakRewards.length - 1)
                    const SizedBox(width: 4),
                ],
              ],
            ),
            const SizedBox(height: AppDimens.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canClaim
                    ? () async {
                        final result = await ref
                            .read(earnControllerProvider.notifier)
                            .claimDailyReward();
                        if (!context.mounted) return;
                        result.when(
                          success: (coins) {
                            Celebration.burst(context);
                            AppToast.success(
                              context,
                              l.earnRewardedYou(coins),
                            );
                          },
                          failure: (f) => AppToast.failure(context, f),
                        );
                      }
                    : null,
                child: Text(canClaim ? l.homeDailyClaim : l.homeDailyClaimed),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.coins,
    required this.day,
    required this.isToday,
    required this.isPast,
  });

  final int coins;
  final int day;
  final bool isToday;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = isToday || isPast;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
      decoration: BoxDecoration(
        color: isToday
            ? scheme.primary.withValues(alpha: 0.22)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: AppDimens.brSm,
        border: isToday ? Border.all(color: scheme.primary) : null,
      ),
      child: Column(
        children: [
          Icon(
            isPast ? Icons.check_circle : Icons.monetization_on,
            size: 15,
            color: active ? AppTheme.coin : scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 2),
          Text(
            '$coins',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: active ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
