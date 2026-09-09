import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../data/redemption_repository.dart';
import 'widgets/redemption_tile.dart';

/// The user's withdrawal history.
class RedemptionsScreen extends ConsumerWidget {
  const RedemptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final redemptions = ref.watch(myRedemptionsProvider);

    return AppScaffold(
      title: l.redemptionsTitle,
      body: AsyncView(
        value: redemptions,
        onRetry: () => ref.invalidate(myRedemptionsProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.receipt_long_outlined,
              title: l.emptyNothingHere,
              subtitle: l.rewardsTitle,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.lg),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimens.md),
            itemBuilder: (_, i) => RedemptionTile(redemption: list[i]),
          );
        },
      ),
    );
  }
}
