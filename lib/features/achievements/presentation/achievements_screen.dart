import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/state_views.dart';
import '../data/achievement_repository.dart';
import 'widgets/badges_grid.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final achievements = ref.watch(achievementsProvider);

    return AppScaffold(
      title: l.achievementsTitle,
      body: AsyncView(
        value: achievements,
        onRetry: () => ref.invalidate(achievementsProvider),
        data: (items) {
          if (items.isEmpty) {
            return EmptyView(
              icon: Icons.military_tech_outlined,
              title: l.emptyNothingHere,
            );
          }
          return BadgesGrid(
            items: items,
            onTap: (view) {
              // Unlocking is written by the wallet trigger; the coins are paid
              // by the same trigger on the next write, so there is nothing for
              // the client to claim. Tapping explains state instead.
              AppToast.info(
                context,
                view.isUnlocked
                    ? '${view.achievement.title} — ${l.achievementsUnlocked}'
                    : view.achievement.description,
              );
            },
          );
        },
      ),
    );
  }
}
