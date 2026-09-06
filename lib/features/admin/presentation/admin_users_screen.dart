import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/format_extensions.dart';
import '../../../core/extensions/vip_level_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_pill.dart';
import '../data/admin_repository.dart';
import '../domain/admin_providers.dart';
import 'widgets/admin_gate.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final page = ref.watch(adminUsersProvider);

    return AdminGate(
      title: l.adminUsers,
      child: AsyncView(
        value: page,
        onRetry: () => ref.invalidate(adminUsersProvider),
        data: (result) {
          final (users, _) = result;
          if (users.isEmpty) {
            return EmptyView(
              icon: Icons.people_outline,
              title: l.emptyNothingHere,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.lg),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimens.sm),
            itemBuilder: (_, i) => _UserTile(user: users[i]),
          );
        },
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return GlassCard(
      onTap: () => _showActions(context, ref),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName?.trim().isNotEmpty ?? false
                      ? user.displayName!
                      : (user.email ?? user.uid),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  user.uid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimens.xs),
                Row(
                  children: [
                    if (user.status != 'active')
                      StatusPill.forStatus(user.status),
                    if (user.vipLevel.isVipTier) ...[
                      const SizedBox(width: AppDimens.xs),
                      Icon(
                        user.vipLevel.vipIcon,
                        size: 14,
                        color: user.vipLevel.vipColor,
                      ),
                    ],
                    if (user.countryCode != null) ...[
                      const SizedBox(width: AppDimens.sm),
                      Text(
                        user.countryCode!,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            user.coins.compact,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Adjust coins'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _adjustCoins(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: Text(l.vipTitle),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _setVip(context, ref);
              },
            ),
            ListTile(
              leading: Icon(
                user.status == 'banned' ? Icons.lock_open : Icons.block,
              ),
              title: Text(user.status == 'banned' ? 'Unban' : 'Ban'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final result = await ref
                    .read(adminRepositoryProvider)
                    .setAccountStatus(
                      uid: user.uid,
                      status: user.status == 'banned' ? 'active' : 'banned',
                    );
                if (!context.mounted) return;
                result.when(
                  success: (_) {
                    ref.invalidate(adminUsersProvider);
                    AppToast.success(context, l.commonDone);
                  },
                  failure: (f) => AppToast.failure(context, f),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adjustCoins(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController();
    final reason = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust coins'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                // Negative is how coins are clawed back — CPAlead has no
                // reversal macro, so that is a manual operation.
                helperText: 'Negative to deduct',
              ),
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Reason'),
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
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final value = int.tryParse(amount.text.trim());
    if (value == null || value == 0) {
      AppToast.error(context, 'Enter a non-zero amount.');
      return;
    }

    final result = await ref
        .read(adminRepositoryProvider)
        .adjustCoins(
          uid: user.uid,
          amount: value,
          reason: reason.text.trim().isEmpty
              ? 'Admin adjustment'
              : reason.text.trim(),
        );
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(adminUsersProvider);
        AppToast.success(context, 'Applied');
      },
      failure: (f) => AppToast.failure(context, f),
    );
  }

  Future<void> _setVip(BuildContext context, WidgetRef ref) async {
    final tier = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in const [
              'none',
              'bronze',
              'silver',
              'gold',
              'diamond',
            ])
              ListTile(
                leading: Icon(t.vipIcon, color: t.vipColor),
                title: Text(t.vipLabel),
                onTap: () => Navigator.of(context).pop(t),
              ),
          ],
        ),
      ),
    );
    if (tier == null || !context.mounted) return;

    final result = await ref
        .read(adminRepositoryProvider)
        .setVipLevel(uid: user.uid, level: tier);
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(adminUsersProvider);
        AppToast.success(context, tier.vipLabel);
      },
      failure: (f) => AppToast.failure(context, f),
    );
  }
}
