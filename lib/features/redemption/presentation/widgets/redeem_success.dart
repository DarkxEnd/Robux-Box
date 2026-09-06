import 'package:flutter/material.dart';

import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/celebration.dart';
import '../../../../models/reward.dart';

/// Confirms the request was accepted.
///
/// Careful with the wording: the coins are gone but the reward is not
/// delivered yet. Saying "done" here is what produces support tickets an hour
/// later asking where the code is.
Future<void> showRedeemSuccess(BuildContext context, Reward reward) async {
  Celebration.burst(context);
  await showDialog<void>(
    context: context,
    builder: (context) {
      final l = AppLocalizations.of(context);
      final theme = Theme.of(context);
      return AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppDimens.md),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 42, color: AppTheme.success),
            ),
            const SizedBox(height: AppDimens.xl),
            Text(reward.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppDimens.sm),
            Text(
              l.rewardsRequested,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.commonDone),
            ),
          ),
        ],
      );
    },
  );
}
