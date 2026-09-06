import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/redemption_repository.dart';
import '../domain/reward_brand.dart';
import 'widgets/brand_category_card.dart';
import 'widgets/brand_rewards_sheet.dart';

/// The rewards catalogue, grouped by brand.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rewards = ref.watch(rewardsProvider);
    final balance = ref.watch(balanceProvider);

    return ListView(
      padding: AppDimens.listBottomPadding,
      children: [
        SectionHeader(
          title: l.rewardsTitle,
          actionLabel: l.redemptionsTitle,
          onAction: () => context.push(Routes.redemptions),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: GlassCard(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: AppTheme.coin),
                const SizedBox(width: AppDimens.md),
                Expanded(child: Text(l.homeBalance)),
                Text(
                  '$balance',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.coin,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        AsyncView(
          value: rewards,
          onRetry: () => ref.invalidate(rewardsProvider),
          loading: const Padding(
            padding: EdgeInsets.all(AppDimens.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyView(
                icon: Icons.card_giftcard_outlined,
                title: l.emptyNothingHere,
              );
            }
            final grouped = RewardBrand.group(list);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppDimens.md,
                mainAxisSpacing: AppDimens.md,
                childAspectRatio: 1.35,
                children: [
                  for (final entry in grouped.entries)
                    BrandCategoryCard(
                      brand: entry.key,
                      count: entry.value.length,
                      onTap: () => showBrandRewardsSheet(
                        context,
                        entry.key,
                        entry.value,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
