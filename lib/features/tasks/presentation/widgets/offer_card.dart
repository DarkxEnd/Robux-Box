import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/format_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../models/offer.dart';

/// One featured offer.
class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.offer, required this.onTap});

  final Offer offer;
  final VoidCallback onTap;

  IconData get _categoryIcon => switch (offer.category) {
    'survey' => Icons.poll_outlined,
    'app_install' => Icons.download_outlined,
    'signup' => Icons.how_to_reg_outlined,
    'game' => Icons.sports_esports_outlined,
    _ => Icons.task_alt_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppDimens.brSm,
            child: SizedBox(
              width: 52,
              height: 52,
              child: offer.imageUrl.isEmpty
                  ? ColoredBox(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                      child: Icon(
                        _categoryIcon,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: offer.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => ColoredBox(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.14,
                        ),
                        child: Icon(
                          _categoryIcon,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (offer.description.isNotEmpty)
                  Text(
                    offer.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: AppDimens.xs),
                Row(
                  children: [
                    _Difficulty(level: offer.difficulty),
                    const SizedBox(width: AppDimens.sm),
                    Text(
                      offer.provider.displayName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // "up to", because the credit depends on geo tier, VIP
              // multiplier and what the provider ultimately reports.
              Text(
                'up to',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.monetization_on,
                    size: 14,
                    color: AppTheme.coin,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    offer.estimatedCoins.compact,
                    style: const TextStyle(
                      color: AppTheme.coin,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Difficulty extends StatelessWidget {
  const _Difficulty({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < level
                  ? (level == 1
                        ? AppTheme.success
                        : level == 2
                        ? AppTheme.warning
                        : AppTheme.danger)
                  : scheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}
