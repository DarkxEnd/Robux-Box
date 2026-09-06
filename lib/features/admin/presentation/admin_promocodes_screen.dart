import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/format_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_pill.dart';
import '../data/admin_repository.dart';
import '../domain/admin_providers.dart';
import 'widgets/admin_gate.dart';

class AdminPromocodesScreen extends ConsumerWidget {
  const AdminPromocodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final codes = ref.watch(adminPromocodesProvider);

    return AdminGate(
      title: l.adminPromocodes,
      child: Stack(
        children: [
          AsyncView(
            value: codes,
            onRetry: () => ref.invalidate(adminPromocodesProvider),
            data: (list) {
              if (list.isEmpty) {
                return EmptyView(
                  icon: Icons.local_offer_outlined,
                  title: l.emptyNothingHere,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.lg,
                  AppDimens.lg,
                  AppDimens.lg,
                  AppDimens.xxxl + AppDimens.xl,
                ),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppDimens.sm),
                itemBuilder: (_, i) {
                  final code = list[i];
                  return GlassCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                code.code,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                '+${code.rewardCoins.compact} · '
                                '${code.redemptionCount} used'
                                '${code.maxRedemptions < 0 ? '' : ' / ${code.maxRedemptions}'}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        StatusPill(
                          label: code.isUsable ? 'Active' : 'Inactive',
                          color: code.isUsable
                              ? AppTheme.success
                              : Colors.grey,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          Positioned(
            right: AppDimens.lg,
            bottom: AppDimens.lg,
            child: FloatingActionButton.extended(
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New code'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final code = TextEditingController();
    final coins = TextEditingController();
    final maxUses = TextEditingController(text: '-1');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New promo code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Code'),
            ),
            TextField(
              controller: coins,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reward coins'),
            ),
            TextField(
              controller: maxUses,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Max redemptions',
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final codeError = Validators.promoCode(code.text);
    final reward = int.tryParse(coins.text.trim());
    if (codeError != null) {
      AppToast.error(context, codeError);
      return;
    }
    if (reward == null || reward <= 0) {
      AppToast.error(context, 'Reward must be a positive number.');
      return;
    }

    final result = await ref.read(adminRepositoryProvider).upsertPromocode(
          code: code.text.trim().toUpperCase(),
          rewardCoins: reward,
          maxRedemptions: int.tryParse(maxUses.text.trim()) ?? -1,
        );
    if (!context.mounted) return;
    result.when(
      success: (_) => AppToast.success(context, 'Created'),
      failure: (f) => AppToast.failure(context, f),
    );
  }
}
