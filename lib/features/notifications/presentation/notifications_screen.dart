import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/providers.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/app_notification.dart';
import '../data/notification_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = ref.watch(notificationsProvider);
    final uid = ref.watch(currentUidProvider);

    return AppScaffold(
      title: l.notificationsTitle,
      actions: [
        IconButton(
          tooltip: l.notificationsMarkAllRead,
          icon: const Icon(Icons.done_all),
          onPressed: uid == null
              ? null
              : () => ref.read(notificationRepositoryProvider).markAllRead(uid),
        ),
      ],
      body: AsyncView(
        value: items,
        onRetry: () => ref.invalidate(notificationsProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.notifications_none,
              title: l.emptyNothingHere,
              subtitle: l.notificationsEnableBody,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.lg),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimens.sm),
            itemBuilder: (_, i) => _Tile(notification: list[i]),
          );
        },
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.notification});

  final AppNotification notification;

  IconData get _icon => switch (notification.type) {
    'redemption' => Icons.card_giftcard,
    'offerwall' => Icons.task_alt,
    'vip' => Icons.workspace_premium,
    'support' => Icons.support_agent,
    'achievement' => Icons.military_tech,
    _ => Icons.notifications,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uid = ref.watch(currentUidProvider);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: AppDimens.brLg,
        ),
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) {
        if (uid != null) {
          ref.read(notificationRepositoryProvider).delete(uid, notification.id);
        }
      },
      child: GlassCard(
        onTap: () {
          if (uid != null && !notification.isRead) {
            ref
                .read(notificationRepositoryProvider)
                .markRead(uid, notification.id);
          }
          final route = notification.deeplink;
          if (route != null && Routes.isKnown(route)) context.push(route);
        },
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: AppDimens.brSm,
              ),
              child: Icon(_icon, size: 19, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: notification.isRead
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(notification.body, style: theme.textTheme.bodySmall),
                  if (notification.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.createdAt!.relative,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
