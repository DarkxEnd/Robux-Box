import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/vip_level_extensions.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../models/reward.dart';
import '../../../profile/data/user_repository.dart';
import '../../../wallet/data/wallet_repository.dart';
import '../../domain/reward_brand.dart';
import 'redeem_sheet.dart';
import 'reward_card.dart';

Future<void> showBrandRewardsSheet(
  BuildContext context,
  RewardBrand brand,
  List<Reward> rewards,
) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BrandRewardsSheet(brand: brand, rewards: rewards),
    );

/// The cards for one brand.
class BrandRewardsSheet extends ConsumerWidget {
  const BrandRewardsSheet({
    super.key,
    required this.brand,
    required this.rewards,
  });

  final RewardBrand brand;
  final List<Reward> rewards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final balance = ref.watch(balanceProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.xl,
              AppDimens.sm,
              AppDimens.xl,
              AppDimens.md,
            ),
            child: Row(
              children: [
                Icon(brand.icon, color: brand.color),
                const SizedBox(width: AppDimens.md),
                Text(
                  brand.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppDimens.lg,
                0,
                AppDimens.lg,
                AppDimens.xxl,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppDimens.md,
                mainAxisSpacing: AppDimens.md,
                childAspectRatio: 0.78,
              ),
              itemCount: rewards.length,
              itemBuilder: (_, i) {
                final reward = rewards[i];
                final lock = reward.lockFor(
                  balance: balance,
                  userVipRank: user?.effectiveVipLevel.vipRank ?? 0,
                  countryCode: user?.countryCode,
                );

                return RewardCard(
                  reward: reward,
                  lock: lock,
                  coinsShort: (reward.coinCost - balance).clamp(0, 1 << 31),
                  onTap: () {
                    if (lock == null) {
                      showRedeemSheet(context, reward);
                      return;
                    }
                    // Each lock has a different remedy, so each gets its own
                    // message rather than a generic "not available".
                    AppToast.info(
                      context,
                      switch (lock) {
                        RewardLock.insufficientCoins =>
                          l.rewardsNeedMore(reward.coinCost - balance),
                        RewardLock.outOfStock => l.rewardsOutOfStock,
                        RewardLock.vipRequired =>
                          l.rewardsVipOnly(reward.minVipLevel.vipLabel),
                        RewardLock.regionLocked => l.rewardsRegionLocked,
                        RewardLock.inactive => l.commonComingSoon,
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
