import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/offerwall_service.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/offerwall.dart';
import '../data/offers_repository.dart';
import 'widgets/offer_card.dart';

/// The offerwall hub: the enabled providers, then featured offers.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  static String _routeFor(OfferwallProvider p) => switch (p) {
    OfferwallProvider.cpx => Routes.offerwall,
    OfferwallProvider.cpalead => Routes.offerwallCpalead,
    OfferwallProvider.lootwalls => Routes.offerwallLootwalls,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final offers = ref.watch(offersProvider);

    return ListView(
      padding: AppDimens.listBottomPadding,
      children: [
        SectionHeader(title: l.tasksTitle, subtitle: l.tasksSubtitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: Column(
            children: [
              for (final provider in OfferwallService.ordered) ...[
                _ProviderTile(
                  provider: provider,
                  onTap: () => context.push(_routeFor(provider)),
                ),
                if (provider != OfferwallService.ordered.last)
                  const SizedBox(height: AppDimens.md),
              ],
            ],
          ),
        ),
        SectionHeader(title: l.commonAll),
        AsyncView(
          value: offers,
          onRetry: () => ref.invalidate(offersProvider),
          loading: const Padding(
            padding: EdgeInsets.all(AppDimens.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          data: (list) {
            if (list.isEmpty) {
              // Not an error: featured offers are curated and often empty.
              // The provider tiles above are the real entry point.
              return Padding(
                padding: const EdgeInsets.all(AppDimens.xl),
                child: Text(
                  l.tasksSubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
              child: Column(
                children: [
                  for (final offer in list) ...[
                    OfferCard(
                      offer: offer,
                      onTap: () => context.push(_routeFor(offer.provider)),
                    ),
                    const SizedBox(height: AppDimens.sm),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider, required this.onTap});

  final OfferwallProvider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final (icon, color) = switch (provider) {
      OfferwallProvider.cpx => (Icons.poll_outlined, AppTheme.primary),
      OfferwallProvider.cpalead => (Icons.apps_outlined, AppTheme.accent),
      OfferwallProvider.lootwalls => (Icons.explore_outlined, AppTheme.success),
    };

    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: AppDimens.brSm,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppDimens.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(provider.displayName, style: theme.textTheme.titleSmall),
                Text(
                  provider.supportsReversal
                      ? l.tasksSubtitle
                      // Worth calling out: CPAlead has no reversal macro, so
                      // a rejected offer is clawed back manually instead.
                      : l.tasksReversalNote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
