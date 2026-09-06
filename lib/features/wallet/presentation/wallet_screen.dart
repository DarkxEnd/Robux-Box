import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/format_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_counter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/transaction.dart';
import '../../../models/wallet.dart';
import '../data/wallet_repository.dart';

/// Balance, totals and transaction history.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final wallet = ref.watch(walletProvider).valueOrNull ??
        const Wallet.empty('');
    final transactions = ref.watch(transactionsProvider);

    return AppScaffold(
      title: l.walletTitle,
      actions: [
        IconButton(
          tooltip: l.redemptionsTitle,
          icon: const Icon(Icons.receipt_long_outlined),
          onPressed: () => context.push(Routes.redemptions),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: GlassCard(
              child: Column(
                children: [
                  Text(l.homeBalance,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppDimens.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on,
                          color: AppTheme.coin, size: 28),
                      const SizedBox(width: AppDimens.sm),
                      AnimatedCounter(value: wallet.balance),
                    ],
                  ),
                  const SizedBox(height: AppDimens.xl),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: l.walletEarned,
                          value: wallet.lifetimeEarned,
                          color: AppTheme.success,
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          label: l.walletSpent,
                          value: wallet.lifetimeSpent,
                          color: AppTheme.warning,
                        ),
                      ),
                      if (wallet.pendingRedemptionCoins > 0)
                        Expanded(
                          child: _Stat(
                            label: l.walletPending,
                            value: wallet.pendingRedemptionCoins,
                            color: AppTheme.accent,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SectionHeader(title: l.walletHistory),
          AsyncView(
            value: transactions,
            onRetry: () => ref.invalidate(transactionsProvider),
            loading: const Padding(
              padding: EdgeInsets.all(AppDimens.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
            data: (items) {
              if (items.isEmpty) {
                return EmptyView(
                  icon: Icons.receipt_long_outlined,
                  title: l.walletNoTransactions,
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                child: Column(
                  children: [
                    for (final tx in items) ...[
                      _TransactionTile(transaction: tx),
                      const SizedBox(height: AppDimens.sm),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.compact,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final AppTransaction transaction;

  IconData get _icon => switch (transaction.type) {
        TxType.rewardedAd || TxType.rewardedInterstitial =>
          Icons.play_circle_outline,
        TxType.offerwall => Icons.task_alt,
        TxType.offerwallReversal => Icons.undo,
        TxType.dailyReward || TxType.dailyStreak => Icons.calendar_today,
        TxType.spin => Icons.casino,
        TxType.chest => Icons.card_giftcard,
        TxType.referralBonus || TxType.referralShare => Icons.group_add,
        TxType.achievement => Icons.military_tech,
        TxType.vipDailyBonus || TxType.vipPurchase => Icons.workspace_premium,
        TxType.redemption => Icons.redeem,
        TxType.redemptionRefund => Icons.replay,
        TxType.rateApp => Icons.star,
        TxType.adminAdjustment => Icons.admin_panel_settings,
        TxType.other => Icons.swap_horiz,
      };

  String _label(AppLocalizations l) {
    final description = transaction.description;
    if (description != null && description.isNotEmpty) return description;
    return switch (transaction.type) {
      TxType.rewardedAd || TxType.rewardedInterstitial => l.earnWatchAd,
      TxType.offerwall => l.tasksTitle,
      TxType.offerwallReversal => l.tasksReversalNote,
      TxType.dailyReward || TxType.dailyStreak => l.homeDailyReward,
      TxType.spin => l.earnSpinWheel,
      TxType.chest => l.earnLuckyChest,
      TxType.referralBonus || TxType.referralShare => l.referralsTitle,
      TxType.achievement => l.achievementsTitle,
      TxType.vipDailyBonus || TxType.vipPurchase => l.vipTitle,
      TxType.redemption => l.rewardsRedeem,
      TxType.redemptionRefund => l.redemptionRefunded,
      TxType.rateApp => l.earnRateApp,
      _ => l.walletHistory,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (transaction.isCredit ? AppTheme.success : AppTheme.danger)
                  .withValues(alpha: 0.14),
              borderRadius: AppDimens.brSm,
            ),
            child: Icon(
              _icon,
              size: 18,
              color: transaction.isCredit ? AppTheme.success : AppTheme.danger,
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(l),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                if (transaction.createdAt != null)
                  Text(
                    transaction.createdAt!.relative,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          CoinAmount(coins: transaction.coins, signed: true),
        ],
      ),
    );
  }
}
