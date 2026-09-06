import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../models/app_user.dart';

/// Today's three suggested actions, with progress.
///
/// Purely a nudge — completing a "mission" grants nothing by itself; the
/// underlying action is what pays. Framing them as goals rather than rewards
/// keeps that honest.
class MissionsSection extends ConsumerWidget {
  const MissionsSection({super.key, required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    final watched = user?.adsWatchedTodayEffective ?? 0;
    final cap = user?.maxAdsPerDay ?? 40;

    final missions = <_Mission>[
      _Mission(
        icon: Icons.play_circle_outline,
        label: l.earnWatchAd,
        progress: (watched / (cap == 0 ? 1 : cap)).clamp(0.0, 1.0),
        detail: '$watched / $cap',
        route: Routes.earn,
        color: AppTheme.primary,
      ),
      _Mission(
        icon: Icons.task_alt_outlined,
        label: l.tasksTitle,
        progress: 0,
        detail: l.tasksOpenWall,
        route: Routes.tasks,
        color: AppTheme.accent,
      ),
      _Mission(
        icon: Icons.group_add_outlined,
        label: l.referralsTitle,
        progress: 0,
        detail: l.referralsInvite,
        route: Routes.referrals,
        color: AppTheme.success,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.homeMissions),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: Column(
            children: [
              for (final m in missions) ...[
                GlassCard(
                  onTap: () => context.push(m.route),
                  padding: const EdgeInsets.all(AppDimens.md),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: m.color.withValues(alpha: 0.16),
                          borderRadius: AppDimens.brSm,
                        ),
                        child: Icon(m.icon, size: 19, color: m.color),
                      ),
                      const SizedBox(width: AppDimens.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: AppDimens.brPill,
                              child: LinearProgressIndicator(
                                value: m.progress,
                                minHeight: 5,
                                color: m.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDimens.md),
                      Text(
                        m.detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (m != missions.last) const SizedBox(height: AppDimens.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Mission {
  const _Mission({
    required this.icon,
    required this.label,
    required this.progress,
    required this.detail,
    required this.route,
    required this.color,
  });

  final IconData icon;
  final String label;
  final double progress;
  final String detail;
  final String route;
  final Color color;
}
