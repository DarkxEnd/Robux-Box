import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/format_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../models/redemption.dart';
import '../data/admin_repository.dart';
import '../domain/admin_providers.dart';
import 'widgets/admin_gate.dart';
import 'widgets/tier_filter_row.dart';

/// The withdrawal queue.
class AdminRedemptionsScreen extends ConsumerWidget {
  const AdminRedemptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final filter = ref.watch(redemptionFilterProvider);
    final redemptions = ref.watch(adminRedemptionsProvider);

    return AdminGate(
      title: l.adminRedemptions,
      child: Column(
        children: [
          TierFilterRow(
            selected: filter,
            onSelected: (v) =>
                ref.read(redemptionFilterProvider.notifier).state = v,
            options: [
              ('pending', l.redemptionPending),
              ('processing', l.redemptionProcessing),
              ('completed', l.redemptionCompleted),
              ('rejected', l.redemptionRejected),
              (null, l.commonAll),
            ],
          ),
          Expanded(
            child: AsyncView(
              value: redemptions,
              onRetry: () => ref.invalidate(adminRedemptionsProvider),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyView(
                    icon: Icons.inbox_outlined,
                    title: l.emptyNothingHere,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppDimens.lg),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimens.sm),
                  itemBuilder: (_, i) => _Tile(redemption: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.redemption});

  final Redemption redemption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final destination = redemption.robloxUsername ?? redemption.email ?? '—';

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
          const SizedBox(height: AppDimens.xs),
          SelectableText(
            destination,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
          Text(
            '${redemption.coinCost.compact} · '
            '${redemption.createdAt?.relative ?? ''}',
            style: theme.textTheme.labelSmall,
          ),

          if (!redemption.status.isTerminal) ...[
            const SizedBox(height: AppDimens.md),
            Row(
              children: [
                if (redemption.status == RedemptionStatus.pending)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _process(context, ref, 'processing'),
                      child: const Text('Start'),
                    ),
                  ),
                if (redemption.status == RedemptionStatus.pending)
                  const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _complete(context, ref),
                    child: const Text('Deliver'),
                  ),
                ),
                const SizedBox(width: AppDimens.sm),
                IconButton(
                  tooltip: 'Reject and refund',
                  icon: const Icon(Icons.close),
                  onPressed: () => _reject(context, ref),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _process(
    BuildContext context,
    WidgetRef ref,
    String status, {
    String note = '',
  }) async {
    final result = await ref
        .read(adminRepositoryProvider)
        .processRedemption(id: redemption.id, status: status, note: note);
    if (!context.mounted) return;
    result.when(
      success: (_) => AppToast.success(context, status),
      failure: (f) => AppToast.failure(context, f),
    );
  }

  /// Delivering asks for the code, which is what the user actually receives.
  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final code = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deliver reward'),
        content: TextField(
          controller: code,
          decoration: const InputDecoration(
            labelText: 'Gift card code',
            helperText: 'Shown to the user in their redemption history',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deliver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _process(context, ref, 'completed', note: code.text.trim());
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject and refund'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _process(context, ref, 'rejected', note: reason.text.trim());
  }
}
