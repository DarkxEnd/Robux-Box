import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/glass_card.dart';
import 'widgets/admin_gate.dart';

/// The admin home: one tile per area.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    final tiles = <(IconData, String, String)>[
      (Icons.people_outline, l.adminUsers, Routes.adminUsers),
      (
        Icons.receipt_long_outlined,
        l.adminRedemptions,
        Routes.adminRedemptions,
      ),
      (Icons.card_giftcard_outlined, l.adminRewards, Routes.adminRewards),
      (Icons.local_offer_outlined, l.adminPromocodes, Routes.adminPromocodes),
      (Icons.campaign_outlined, l.adminBroadcast, Routes.adminBroadcast),
      (Icons.analytics_outlined, l.adminAnalytics, Routes.adminAnalytics),
      (Icons.support_agent_outlined, l.adminTickets, Routes.adminTickets),
      (Icons.flag_outlined, l.adminReports, Routes.adminReports),
      (
        Icons.workspace_premium_outlined,
        l.adminVipPurchases,
        Routes.adminVipPurchases,
      ),
      (Icons.shield_outlined, l.adminManageAdmins, Routes.adminAdmins),
    ];

    return AdminGate(
      title: l.adminTitle,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppDimens.lg),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppDimens.md,
          mainAxisSpacing: AppDimens.md,
          childAspectRatio: 1.25,
        ),
        itemCount: tiles.length,
        itemBuilder: (_, i) {
          final (icon, label, route) = tiles[i];
          return GlassCard(
            onTap: () => context.push(route),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppDimens.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
