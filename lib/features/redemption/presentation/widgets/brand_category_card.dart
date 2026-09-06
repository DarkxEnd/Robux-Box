import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../domain/reward_brand.dart';

/// A brand tile on the rewards grid.
class BrandCategoryCard extends StatelessWidget {
  const BrandCategoryCard({
    super.key,
    required this.brand,
    required this.count,
    required this.onTap,
  });

  final RewardBrand brand;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              brand.color.withValues(alpha: 0.9),
              brand.color.withValues(alpha: 0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppDimens.brLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(brand.icon, color: Colors.white, size: 28),
            const Spacer(),
            Text(
              brand.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
