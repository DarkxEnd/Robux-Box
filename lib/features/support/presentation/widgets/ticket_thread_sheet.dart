import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/format_extensions.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../models/support_ticket.dart';
import '../../data/support_repository.dart';

Future<void> showTicketThreadSheet(BuildContext context, SupportTicket ticket) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: TicketThreadSheet(ticket: ticket),
      ),
    );

/// The conversation on one ticket.
class TicketThreadSheet extends ConsumerStatefulWidget {
  const TicketThreadSheet({super.key, required this.ticket});

  final SupportTicket ticket;

  @override
  ConsumerState<TicketThreadSheet> createState() => _TicketThreadSheetState();
}

class _TicketThreadSheetState extends ConsumerState<TicketThreadSheet> {
  final _reply = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;

    setState(() => _busy = true);
    final result = await ref.read(supportRepositoryProvider).reply(
          ticketId: widget.ticket.id,
          body: text,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (_) => _reply.clear(),
      failure: (f) => AppToast.failure(context, f),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ticket = widget.ticket;

    // The opening message is stored separately from the replies, so it is
    // prepended here to render as one continuous thread.
    final messages = [
      TicketMessage(
        body: ticket.message,
        fromAdmin: false,
        sentAt: ticket.createdAt,
      ),
      ...ticket.messages,
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.xl,
              AppDimens.sm,
              AppDimens.xl,
              AppDimens.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                StatusPill(
                  label: ticket.status.isOpen ? l.supportOpen : l.supportResolved,
                  color: ticket.status.isOpen
                      ? theme.colorScheme.primary
                      : Colors.grey,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
              itemCount: messages.length,
              itemBuilder: (_, i) => _Bubble(message: messages[i]),
            ),
          ),
          if (ticket.status.isOpen)
            Padding(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reply,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(hintText: l.supportMessage),
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  IconButton.filled(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fromAdmin = message.fromAdmin;

    return Align(
      alignment:
          fromAdmin ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimens.sm),
        padding: const EdgeInsets.all(AppDimens.md),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: fromAdmin
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primary.withValues(alpha: 0.18),
          borderRadius: AppDimens.brMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fromAdmin)
              Text(
                message.authorName ?? 'Support',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(message.body, style: theme.textTheme.bodyMedium),
            if (message.sentAt != null)
              Text(
                message.sentAt!.relative,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
