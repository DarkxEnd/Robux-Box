import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/glass_card.dart';

/// Four shortcuts under the balance card.
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final actions = <(IconData, String, String)>[
      (Icons.emoji_events_outlined, l.leaderboardTitle, Routes.leaderboard),
      (Icons.workspace_premium_outlined, l.vipTitle, Routes.vip),
      (Icons.group_add_outlined, l.referralsTitle, Routes.referrals),
      (Icons.military_tech_outlined, l.achievementsTitle, Routes.achievements),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
      child: Row(
        children: [
          for (final (icon, label, route) in actions) ...[
            Expanded(
              child: GlassCard(
                onTap: () => context.push(route),
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.lg,
                  horizontal: AppDimens.sm,
                ),
                child: Column(
                  children: [
                    Icon(icon, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: AppDimens.sm),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (route != actions.last.$3) const SizedBox(width: AppDimens.md),
          ],
        ],
      ),
    );
  }
}
