import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/extensions/format_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/support_ticket.dart';
import '../data/admin_repository.dart';
import '../domain/admin_providers.dart';
import 'widgets/admin_gate.dart';
import 'widgets/tier_filter_row.dart';

class AdminTicketsScreen extends ConsumerWidget {
  const AdminTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final filter = ref.watch(ticketFilterProvider);
    final tickets = ref.watch(adminTicketsProvider);

    return AdminGate(
      title: l.adminTickets,
      child: Column(
        children: [
          TierFilterRow(
            selected: filter,
            onSelected: (v) => ref.read(ticketFilterProvider.notifier).state = v,
            options: [
              ('open', l.supportOpen),
              ('awaiting_user', 'Awaiting user'),
              ('resolved', l.supportResolved),
              (null, l.commonAll),
            ],
          ),
          Expanded(
            child: AsyncView(
              value: tickets,
              onRetry: () => ref.invalidate(adminTicketsProvider),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyView(
                    icon: Icons.support_agent_outlined,
                    title: l.emptyNothingHere,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppDimens.lg),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimens.sm),
                  itemBuilder: (_, i) => _Tile(ticket: list[i]),
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
  const _Tile({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return GlassCard(
      onTap: () => _reply(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ticket.subject, style: theme.textTheme.titleSmall),
          Text(
            ticket.message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimens.xs),
          Text(
            '${ticket.categoryId} · ${ticket.updatedAt?.relative ?? ''} · '
            '${ticket.messages.length} replies',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Future<void> _reply(BuildContext context, WidgetRef ref) async {
    final body = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ticket.subject),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ticket.message),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: body,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Reply'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(false);
              await ref
                  .read(adminRepositoryProvider)
                  .setTicketStatus(ticket.id, 'resolved');
            },
            child: const Text('Resolve'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || body.text.trim().isEmpty || !context.mounted) {
      return;
    }

    final name = ref.read(authStateProvider).valueOrNull?.displayName;
    final result = await ref.read(adminRepositoryProvider).replyToTicket(
          ticketId: ticket.id,
          body: body.text,
          authorName: name ?? 'Support',
        );
    if (!context.mounted) return;
    result.when(
      success: (_) => AppToast.success(context, 'Sent'),
      failure: (f) => AppToast.failure(context, f),
    );
  }
}
