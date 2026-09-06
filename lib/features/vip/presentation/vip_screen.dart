import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/extensions/vip_level_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../earn/presentation/widgets/earn_reward_dialog.dart';
import '../../../models/app_user.dart';
import '../../profile/data/user_repository.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/vip_repository.dart';

/// The VIP tiers, their benefits, and both ways to buy one.
class VipScreen extends ConsumerStatefulWidget {
  const VipScreen({super.key});

  @override
  ConsumerState<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends ConsumerState<VipScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final iap = ref.read(vipIapServiceProvider);
      iap.initialise();
      // The store flow outlives the buy() call, so the outcome arrives here.
      iap.results.listen((result) {
        if (!mounted) return;
        result.when(
          success: (tier) => AppToast.success(
            context,
            '${AppLocalizations.of(context).vipTitle}: ${tier.vipLabel}',
          ),
          failure: (f) => AppToast.failure(context, f),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final current = user?.effectiveVipLevel ?? 'none';

    return AppScaffold(
      title: l.vipTitle,
      actions: [
        TextButton(
          onPressed: () => ref.read(vipIapServiceProvider).restore(),
          child: Text(l.vipRestore),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: _CurrentTierCard(level: current, user: user),
          ),
          SectionHeader(title: l.vipSubtitle),
          for (final tier in const ['bronze', 'silver', 'gold', 'diamond'])
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.lg,
                0,
                AppDimens.lg,
                AppDimens.md,
              ),
              child: _TierCard(
                tier: tier,
                isCurrent: tier == current,
                // Only an upgrade is offered; buying a tier below the one you
                // hold would silently downgrade you.
                canBuy: tier.vipRank > current.vipRank,
              ),
            ),
        ],
      ),
    );
  }
}

class _CurrentTierCard extends ConsumerWidget {
  const _CurrentTierCard({required this.level, required this.user});

  final String level;
  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final canClaim = user?.canClaimVipBonus ?? false;
    final bonus = AppConstants.vipDailyBonusCoins[level] ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppDimens.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: level.vipGradient),
        borderRadius: AppDimens.brXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(level.vipIcon, color: Colors.white, size: 26),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.vipCurrentTier,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      level.vipLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                l.vipMultiplier(level.vipMultiplier.toStringAsFixed(2)),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (user?.vipExpiresAt != null) ...[
            const SizedBox(height: AppDimens.sm),
            Text(
              l.vipExpiresOn(user!.vipExpiresAt!.shortDate),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
          ],
          if (level.isVipTier) ...[
            const SizedBox(height: AppDimens.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: canClaim
                    ? () async {
                        final result = await ref
                            .read(vipRepositoryProvider)
                            .claimDailyBonus();
                        if (!context.mounted) return;
                        result.when(
                          success: (coins) =>
                              showEarnRewardDialog(context, coins: coins),
                          failure: (f) => AppToast.failure(context, f),
                        );
                      }
                    : null,
                child: Text(
                  canClaim
                      ? '${l.vipClaimBonus} · ${bonus.grouped}'
                      : l.homeDailyClaimed,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TierCard extends ConsumerWidget {
  const _TierCard({
    required this.tier,
    required this.isCurrent,
    required this.canBuy,
  });

  final String tier;
  final bool isCurrent;
  final bool canBuy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final balance = ref.watch(balanceProvider);

    final coinPrice = AppConstants.vipCoinPrices[tier];
    final maxAds = AppConstants.vipMaxAdsPerDay[tier] ?? 40;
    final product = ref.watch(vipIapServiceProvider).productFor(tier);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tier.vipIcon, color: tier.vipColor),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Text(tier.vipLabel, style: theme.textTheme.titleMedium),
              ),
              if (isCurrent)
                const Icon(Icons.check_circle, color: AppTheme.success),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          _Benefit(
            icon: Icons.trending_up,
            text: l.vipMultiplier(tier.vipMultiplier.toStringAsFixed(2)),
          ),
          _Benefit(icon: Icons.ondemand_video, text: l.vipMoreAds(maxAds)),
          _Benefit(
            icon: Icons.card_giftcard,
            text: '${l.vipDailyBonus}: '
                '${(AppConstants.vipDailyBonusCoins[tier] ?? 0).grouped}',
          ),
          if (canBuy) ...[
            const SizedBox(height: AppDimens.lg),
            Row(
              children: [
                // Gold and Diamond are money-only, so coinPrice is absent for
                // them by design rather than by omission.
                if (coinPrice != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: balance < coinPrice
                          ? null
                          : () => _buyWithCoins(context, ref, l),
                      child: Text(
                        '${l.vipBuyWithCoins}\n${coinPrice.compact}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                if (coinPrice != null) const SizedBox(width: AppDimens.md),
                Expanded(
                  child: GradientButton(
                    label: product?.price ??
                        AppConstants.vipMoneyPrices[tier] ??
                        l.vipBuyWithMoney,
                    expand: true,
                    onPressed: () async {
                      final result =
                          await ref.read(vipIapServiceProvider).buy(tier);
                      if (!context.mounted) return;
                      result.when(
                        success: (_) {},
                        failure: (f) => AppToast.failure(context, f),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _buyWithCoins(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${l.vipBuyWithCoins} · ${tier.vipLabel}'),
        content: Text(
          l.rewardsConfirmBody(AppConstants.vipCoinPrices[tier] ?? 0),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result =
        await ref.read(vipRepositoryProvider).purchaseWithCoins(tier);
    if (!context.mounted) return;
    result.when(
      success: (_) => AppToast.success(context, tier.vipLabel),
      failure: (f) => AppToast.failure(context, f),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.xs),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
