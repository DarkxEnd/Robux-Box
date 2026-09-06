import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/vip_level_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/model_utils.dart';
import '../domain/admin_providers.dart';
import 'widgets/admin_gate.dart';

/// Verified VIP purchases, as recorded by `verifyVipPurchase`.
class AdminVipPurchasesScreen extends ConsumerWidget {
  const AdminVipPurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final purchases = ref.watch(adminVipPurchasesProvider);

    return AdminGate(
      title: l.adminVipPurchases,
      child: AsyncView(
        value: purchases,
        onRetry: () => ref.invalidate(adminVipPurchasesProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.workspace_premium_outlined,
              title: l.emptyNothingHere,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.lg),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimens.sm),
            itemBuilder: (_, i) {
              final purchase = list[i];
              final tier = Parse.toStr(purchase['tier'], 'none');
              final created = Parse.toDate(purchase['createdAt']);

              return GlassCard(
                child: Row(
                  children: [
                    Icon(tier.vipIcon, color: tier.vipColor),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${tier.vipLabel} · '
                            '${Parse.toStr(purchase['source'], 'store')}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          SelectableText(
                            Parse.toStr(purchase['uid']),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontFamily: 'monospace'),
                          ),
                          if (created != null)
                            Text(
                              created.toLocal().toString(),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
