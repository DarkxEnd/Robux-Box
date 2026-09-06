import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/format_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/reward.dart';
import '../data/admin_repository.dart';
import '../domain/admin_providers.dart';
import 'widgets/admin_gate.dart';

/// Toggle catalogue entries on and off, and adjust their price and stock.
class AdminRewardsScreen extends ConsumerWidget {
  const AdminRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rewards = ref.watch(adminRewardsProvider);

    return AdminGate(
      title: l.adminRewards,
      child: AsyncView(
        value: rewards,
        onRetry: () => ref.invalidate(adminRewardsProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.card_giftcard_outlined,
              title: l.emptyNothingHere,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.lg),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimens.sm),
            itemBuilder: (_, i) => _Tile(reward: list[i]),
          );
        },
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.reward});

  final Reward reward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return GlassCard(
      onTap: () => _edit(context, ref),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.title, style: theme.textTheme.titleSmall),
                Text(
                  '${reward.coinCost.compact} · '
                  '${reward.stock < 0 ? '∞' : reward.stock} in stock',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Switch(
            value: reward.isActive,
            onChanged: (v) async {
              final result = await ref
                  .read(adminRepositoryProvider)
                  .upsertReward(reward.id, {'isActive': v});
              if (!context.mounted) return;
              result.when(
                success: (_) {},
                failure: (f) => AppToast.failure(context, f),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final cost = TextEditingController(text: '${reward.coinCost}');
    final stock = TextEditingController(text: '${reward.stock}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reward.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cost,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Coin cost'),
            ),
            TextField(
              controller: stock,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Stock',
                helperText: '-1 for unlimited',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final newCost = int.tryParse(cost.text.trim());
    final newStock = int.tryParse(stock.text.trim());
    if (newCost == null || newCost <= 0) {
      // A zero or negative price would let anyone drain the catalogue.
      AppToast.error(context, 'Coin cost must be a positive number.');
      return;
    }

    final result = await ref.read(adminRepositoryProvider).upsertReward(
      reward.id,
      {'coinCost': newCost, if (newStock != null) 'stock': newStock},
    );
    if (!context.mounted) return;
    result.when(
      success: (_) => AppToast.success(context, 'Saved'),
      failure: (f) => AppToast.failure(context, f),
    );
  }
}
