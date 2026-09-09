import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/format_extensions.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_pill.dart';
import '../domain/support_providers.dart';
import 'widgets/new_ticket_sheet.dart';
import 'widgets/ticket_thread_sheet.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tickets = ref.watch(myTicketsProvider);

    return AppScaffold(
      title: l.supportTitle,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showNewTicketSheet(context),
        icon: const Icon(Icons.add),
        label: Text(l.supportNewTicket),
      ),
      body: AsyncView(
        value: tickets,
        onRetry: () => ref.invalidate(myTicketsProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.support_agent_outlined,
              title: l.emptyNothingHere,
              subtitle: l.supportNewTicket,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.lg),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimens.sm),
            itemBuilder: (_, i) {
              final ticket = list[i];
              return GlassCard(
                onTap: () => showTicketThreadSheet(context, ticket),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            ticket.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (ticket.updatedAt != null)
                            Text(
                              ticket.updatedAt!.relative,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.md),
                    Column(
                      children: [
                        StatusPill(
                          label: ticket.status.isOpen
                              ? l.supportOpen
                              : l.supportResolved,
                          color: ticket.status.isOpen
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        if (ticket.hasUnreadForUser) ...[
                          const SizedBox(height: AppDimens.xs),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
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
