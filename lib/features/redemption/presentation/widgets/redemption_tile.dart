import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/format_extensions.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../models/redemption.dart';
import '../../data/redemption_repository.dart';

/// One row of the user's redemption history.
class RedemptionTile extends ConsumerWidget {
  const RedemptionTile({super.key, required this.redemption});

  final Redemption redemption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  redemption.rewardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              StatusPill.forStatus(redemption.status.wire),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          Row(
            children: [
              CoinAmount(coins: -redemption.coinCost, signed: true, size: 14),
              const Spacer(),
              if (redemption.createdAt != null)
                Text(
                  redemption.createdAt!.relative,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),

          if (redemption.hasCode) ...[
            const SizedBox(height: AppDimens.md),
            _CodeBox(
              label: l.redemptionYourCode,
              code: redemption.deliveredCode!,
            ),
          ],

          if (redemption.status.wasRefunded) ...[
            const SizedBox(height: AppDimens.sm),
            Row(
              children: [
                const Icon(Icons.replay, size: 14, color: AppTheme.accent),
                const SizedBox(width: AppDimens.xs),
                Expanded(
                  child: Text(
                    redemption.rejectionReason?.isNotEmpty ?? false
                        ? redemption.rejectionReason!
                        : l.redemptionRefunded,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ],

          // Only a request nobody has started working on can be withdrawn —
          // once it is processing a code may already have been bought.
          if (redemption.status.isCancellableByUser) ...[
            const SizedBox(height: AppDimens.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => _confirmCancel(context, ref, l),
                icon: const Icon(Icons.close, size: 16),
                label: Text(l.redemptionCancel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.redemptionCancel),
        content: Text(l.redemptionRefunded),
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
        await ref.read(redemptionRepositoryProvider).cancel(redemption.id);
    if (!context.mounted) return;
    result.when(
      success: (_) => AppToast.success(context, l.redemptionRefunded),
      failure: (f) => AppToast.failure(context, f),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.label, required this.code});

  final String label;
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.12),
        borderRadius: AppDimens.brMd,
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                SelectableText(
                  code,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                AppToast.success(
                  context,
                  AppLocalizations.of(context).commonCopied,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
