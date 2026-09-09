import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/format_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../models/reward.dart';
import '../../domain/robux_card_art.dart';

/// One catalogue card.
///
/// [lock] is the *reason* it cannot be redeemed, not a boolean — the user
/// needs to know whether they are short of coins, in the wrong country or
/// missing a VIP tier, and each of those has a different next step.
class RewardCard extends StatelessWidget {
  const RewardCard({
    super.key,
    required this.reward,
    required this.onTap,
    this.lock,
    this.coinsShort = 0,
  });

  final Reward reward;
  final VoidCallback onTap;
  final RewardLock? lock;
  final int coinsShort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = RobuxCardArt.assetFor(reward);
    final locked = lock != null;

    return Pressable(
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.62 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppDimens.brLg,
            border: Border.all(
              color: reward.badge.isEmpty
                  ? theme.colorScheme.outlineVariant.withValues(alpha: 0.5)
                  : AppTheme.coin.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.5,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppDimens.radiusLg),
                      ),
                      child: _Art(reward: reward, asset: asset),
                    ),
                  ),
                  if (reward.badge.isNotEmpty)
                    PositionedDirectional(
                      top: AppDimens.sm,
                      start: AppDimens.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.sm,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          gradient: AppTheme.coinGradient,
                          borderRadius: AppDimens.brPill,
                        ),
                        child: Text(
                          reward.badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (locked)
                    PositionedDirectional(
                      top: AppDimens.sm,
                      end: AppDimens.sm,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(
                          switch (lock!) {
                            RewardLock.vipRequired => Icons.workspace_premium,
                            RewardLock.regionLocked => Icons.public_off,
                            RewardLock.outOfStock => Icons.inventory_2_outlined,
                            _ => Icons.lock_outline,
                          },
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimens.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppDimens.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          size: 14,
                          color: AppTheme.coin,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            reward.coinCost.compact,
                            style: const TextStyle(
                              color: AppTheme.coin,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (lock == RewardLock.insufficientCoins &&
                        coinsShort > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${coinsShort.compact} more',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Art extends StatelessWidget {
  const _Art({required this.reward, required this.asset});

  final Reward reward;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    if (reward.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: reward.imageUrl,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _fallback(),
        placeholder: (_, __) => _fallback(),
      );
    }
    if (asset != null) {
      return Image.asset(
        asset!,
        fit: BoxFit.cover,
        // The catalogue is admin-edited and can name an id with no bundled
        // art; without this the whole grid would throw on that one card.
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() => DecoratedBox(
    decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
    child: Center(
      child: Text(
        reward.currency == 'RBX'
            ? '${reward.faceValue.round()}'
            : '\$${reward.faceValue.round()}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}
