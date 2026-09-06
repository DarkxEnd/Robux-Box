import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/r_glyph.dart';
import '../../../models/wallet.dart';
import '../../earn/data/earn_repository.dart';
import '../../notifications/data/notification_repository.dart';
import '../../profile/data/user_repository.dart';
import '../../wallet/data/wallet_repository.dart';
import 'widgets/balance_hero_card.dart';
import 'widgets/daily_reward_card.dart';
import 'widgets/missions_section.dart';
import 'widgets/promo_carousel.dart';
import 'widgets/quick_action_grid.dart';

/// The landing tab.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final wallet = ref.watch(walletProvider).valueOrNull ?? const Wallet.empty('');
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    return RefreshIndicator(
      onRefresh: () async {
        // The wallet and profile are live streams and need no refresh; the
        // tier is a one-shot call, so this is what pull-to-refresh is for.
        ref.invalidate(tierProvider);
        ref.invalidate(homeBannersProvider);
      },
      child: ListView(
        padding: AppDimens.listBottomPadding,
        children: [
          _Header(unread: unread),
          const SizedBox(height: AppDimens.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: BalanceHeroCard(wallet: wallet, user: user),
          ),
          const SizedBox(height: AppDimens.lg),
          const QuickActionGrid(),
          const SizedBox(height: AppDimens.lg),
          const PromoCarousel(),
          const SizedBox(height: AppDimens.lg),
          DailyRewardCard(user: user),
          MissionsSection(user: user),
          const SizedBox(height: AppDimens.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            child: FilledButton.icon(
              onPressed: () => context.push(Routes.earn),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l.earnTitle),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final name = user?.displayName?.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.md,
        AppDimens.sm,
        0,
      ),
      child: Row(
        children: [
          const RGlyph(size: 34),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Text(
              (name != null && name.isNotEmpty) ? name : 'Robux Box',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: () => context.push(Routes.notifications),
            icon: Badge(
              // Badge hides itself when the label is null, so an unread count
              // of zero must not render an empty dot.
              isLabelVisible: unread > 0,
              label: Text('${unread > 99 ? 99 : unread}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            onPressed: () => context.push(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}
