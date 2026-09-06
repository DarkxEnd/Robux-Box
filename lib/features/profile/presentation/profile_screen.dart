import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/providers.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/extensions/vip_level_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/app_user.dart';
import '../../auth/domain/auth_controller.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/user_repository.dart';
import 'widgets/edit_profile_sheet.dart';
import 'widgets/profile_menu_tile.dart';

/// The profile tab: identity, stats and the menu into everything else.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final userAsync = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;

    return AsyncView(
      value: userAsync,
      onRetry: () => ref.invalidate(currentUserProvider),
      data: (user) {
        if (user == null) return const LoadingView();
        return ListView(
          padding: AppDimens.listBottomPadding,
          children: [
            const SizedBox(height: AppDimens.lg),
            _Identity(user: user),
            const SizedBox(height: AppDimens.lg),
            _Stats(user: user),
            const SizedBox(height: AppDimens.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
                child: Column(
                  children: [
                    ProfileMenuTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: l.walletTitle,
                      onTap: () => context.push(Routes.wallet),
                    ),
                    ProfileMenuTile(
                      icon: Icons.receipt_long_outlined,
                      label: l.redemptionsTitle,
                      onTap: () => context.push(Routes.redemptions),
                    ),
                    ProfileMenuTile(
                      icon: Icons.workspace_premium_outlined,
                      label: l.vipTitle,
                      badge: user.effectiveVipLevel.isVipTier
                          ? user.effectiveVipLevel.vipLabel
                          : null,
                      onTap: () => context.push(Routes.vip),
                    ),
                    ProfileMenuTile(
                      icon: Icons.military_tech_outlined,
                      label: l.achievementsTitle,
                      onTap: () => context.push(Routes.achievements),
                    ),
                    ProfileMenuTile(
                      icon: Icons.group_add_outlined,
                      label: l.referralsTitle,
                      onTap: () => context.push(Routes.referrals),
                    ),
                    ProfileMenuTile(
                      icon: Icons.support_agent_outlined,
                      label: l.supportTitle,
                      onTap: () => context.push(Routes.support),
                    ),
                    ProfileMenuTile(
                      icon: Icons.settings_outlined,
                      label: l.settingsTitle,
                      onTap: () => context.push(Routes.settings),
                    ),
                    // Shown only when the ID token actually carries the claim,
                    // which is the same thing the rules and every admin
                    // callable check.
                    if (isAdmin)
                      ProfileMenuTile(
                        icon: Icons.admin_panel_settings_outlined,
                        label: l.adminTitle,
                        onTap: () => context.push(Routes.admin),
                      ),
                    ProfileMenuTile(
                      icon: Icons.logout,
                      label: l.authSignOut,
                      destructive: true,
                      trailing: const SizedBox.shrink(),
                      onTap: () => _confirmSignOut(context, ref, l),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.authSignOut),
        content: Text(l.authSignOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.authSignOut),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

class _Identity extends ConsumerWidget {
  const _Identity({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final vip = user.effectiveVipLevel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
      child: GlassCard(
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.16),
              backgroundImage: (user.photoUrl?.isNotEmpty ?? false)
                  ? CachedNetworkImageProvider(user.photoUrl!)
                  : null,
              child: (user.photoUrl?.isNotEmpty ?? false)
                  ? null
                  : Icon(Icons.person, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: AppDimens.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName?.trim().isNotEmpty ?? false
                              ? user.displayName!
                              : l.profileTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (vip.isVipTier) ...[
                        const SizedBox(width: AppDimens.xs),
                        Icon(vip.vipIcon, size: 16, color: vip.vipColor),
                      ],
                    ],
                  ),
                  if (user.email != null)
                    Text(
                      user.email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  if (user.createdAt != null)
                    Text(
                      l.profileMemberSince(user.createdAt!.shortDate),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showEditProfileSheet(context, user),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stats extends ConsumerWidget {
  const _Stats({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final wallet = ref.watch(walletProvider).valueOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
      child: GlassCard(
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                label: l.homeBalance,
                value: (wallet?.balance ?? 0).compact,
                color: AppTheme.coin,
              ),
            ),
            Expanded(
              child: _Stat(
                label: l.profileLevel(user.level),
                value: '${user.xp.compact} XP',
                color: AppTheme.primary,
              ),
            ),
            Expanded(
              child: _Stat(
                label: l.homeDailyReward,
                value: '${user.dailyStreak}',
                color: AppTheme.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
