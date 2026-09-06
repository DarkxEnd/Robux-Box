import 'package:flutter/material.dart';

import '../../../../core/extensions/format_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/celebration.dart';

/// The "you earned N coins" moment.
///
/// Shown after the server has already credited the coins, never before — the
/// dialog reports a fact, it does not promise one.
Future<void> showEarnRewardDialog(
  BuildContext context, {
  required int coins,
  String? subtitle,
}) async {
  Celebration.burst(context);
  await showDialog<void>(
    context: context,
    builder: (_) => _EarnRewardDialog(coins: coins, subtitle: subtitle),
  );
}

class _EarnRewardDialog extends StatelessWidget {
  const _EarnRewardDialog({required this.coins, this.subtitle});

  final int coins;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(
        AppDimens.xl,
        AppDimens.xxl,
        AppDimens.xl,
        AppDimens.lg,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              gradient: AppTheme.coinGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.monetization_on,
                size: 46, color: Colors.white),
          ),
          const SizedBox(height: AppDimens.xl),
          Text(
            '+${coins.grouped}',
            style: theme.textTheme.displaySmall?.copyWith(
              color: AppTheme.coin,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppDimens.xs),
          Text(
            subtitle ?? 'Added to your wallet',
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
            child: const Text('Nice!'),
          ),
        ),
      ],
    );
  }
}
