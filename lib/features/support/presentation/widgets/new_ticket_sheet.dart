import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/providers.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../data/support_repository.dart';
import '../../domain/support_providers.dart';

Future<void> showNewTicketSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: const NewTicketSheet(),
  ),
);

class NewTicketSheet extends ConsumerStatefulWidget {
  const NewTicketSheet({super.key});

  @override
  ConsumerState<NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends ConsumerState<NewTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String? _categoryId;
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _busy = true);
    final result = await ref
        .read(supportRepositoryProvider)
        .create(
          uid: uid,
          categoryId: _categoryId ?? 'other',
          subject: _subject.text,
          message: _message.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (_) {
        Navigator.of(context).pop();
        AppToast.success(context, AppLocalizations.of(context).supportSent);
      },
      failure: (f) => AppToast.failure(context, f),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final categories =
        ref.watch(ticketCategoriesProvider).valueOrNull ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.xl,
        AppDimens.sm,
        AppDimens.xl,
        AppDimens.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.supportNewTicket,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimens.lg),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: InputDecoration(labelText: l.supportCategory),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c.id, child: Text(c.title)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
              validator: (v) => v == null ? Validators.notEmpty(null) : null,
            ),
            const SizedBox(height: AppDimens.lg),
            TextFormField(
              controller: _subject,
              decoration: InputDecoration(labelText: l.supportSubject),
              validator: (v) => Validators.minLength(v, 4),
            ),
            const SizedBox(height: AppDimens.lg),
            TextFormField(
              controller: _message,
              maxLines: 5,
              maxLength: 2000,
              decoration: InputDecoration(labelText: l.supportMessage),
              validator: (v) => Validators.minLength(v, 10),
            ),
            const SizedBox(height: AppDimens.md),
            GradientButton(
              label: l.supportSend,
              enabled: !_busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
