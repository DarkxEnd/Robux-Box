import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/config/providers.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/gradient_button.dart';

Future<void> showReportSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const ReportSheet(),
      ),
    );

/// "Report a problem" — a lightweight bug report written to `reports/`.
///
/// Separate from support tickets: this is fire-and-forget diagnostics with no
/// reply thread, which is what most people actually want when something looks
/// broken. Device and version are attached automatically, since a report
/// without them is usually unactionable.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key});

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);

    try {
      final uid = ref.read(currentUidProvider);
      final device = await ref.read(secureStorageProvider).context();
      final info = await PackageInfo.fromPlatform();

      await ref.read(firestoreProvider).collection(FsPaths.reports).add({
        'uid': uid,
        'message': _message.text.trim(),
        'appVersion': '${info.version}+${info.buildNumber}',
        'platform': device['platform'],
        'osVersion': device['osVersion'],
        'model': device['model'],
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.success(context, AppLocalizations.of(context).supportSent);
    } catch (_) {
      if (mounted) {
        AppToast.error(context, AppLocalizations.of(context).errorGeneric);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

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
            Text(l.settingsReport,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimens.lg),
            TextFormField(
              controller: _message,
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(hintText: l.supportMessage),
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
