import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/vip_level_extensions.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../models/app_user.dart';
import '../../../../models/wallet.dart';
import '../../../redemption/data/redemption_repository.dart';

/// The balance card at the top of the home screen.
class BalanceHeroCard extends ConsumerWidget {
  const BalanceHeroCard({super.key, required this.wallet, required this.user});

  final Wallet wallet;
  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final vip = user?.effectiveVipLevel ?? 'none';
    final pending = ref.watch(pendingRedemptionCoinsProvider);

    // Integer division on purpose: showing "≈ 12.4 Robux" invites people to
    // expect fractional payouts that the reward catalogue cannot deliver.
    final robux = wallet.balance ~/ AppConstants.coinsPerRobux;

    return Pressable(
      onTap: () => context.push(Routes.wallet),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimens.xl),
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: AppDimens.brXl,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.35),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l.homeBalance,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (vip.isVipTier)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.md,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: AppDimens.brPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(vip.vipIcon, size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          vip.vipLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.monetization_on,
                    color: AppTheme.coin, size: 34),
                const SizedBox(width: AppDimens.sm),
                Flexible(
                  child: AnimatedCounter(
                    value: wallet.balance,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.xs),
            Text(
              l.homeWorthRobux(robux),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13.5,
              ),
            ),
            if (pending > 0) ...[
              const SizedBox(height: AppDimens.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.md,
                  vertical: AppDimens.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: AppDimens.brSm,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: Colors.white),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: Text(
                        // Explains a balance that dropped after a withdrawal
                        // request, which otherwise reads as coins going
                        // missing.
                        '${l.walletPending}: $pending ${l.homeCoins}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
