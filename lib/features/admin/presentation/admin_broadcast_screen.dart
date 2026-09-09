import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/gradient_button.dart';
import '../data/admin_repository.dart';
import 'widgets/admin_gate.dart';

/// Sends a push to every user, or to a segment.
class AdminBroadcastScreen extends ConsumerStatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  ConsumerState<AdminBroadcastScreen> createState() =>
      _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends ConsumerState<AdminBroadcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _audience = 'all';
  String _deeplink = '';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Irreversible and reaches every user at once, so it gets an explicit
    // confirmation rather than firing on the first tap.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send to everyone?'),
        content: Text(
          'This sends a push notification to the "$_audience" audience. '
          'It cannot be recalled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await ref
        .read(adminRepositoryProvider)
        .broadcast(
          title: _title.text,
          body: _body.text,
          audience: _audience,
          deeplink: _deeplink,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (sent) {
        _title.clear();
        _body.clear();
        AppToast.success(context, 'Sent to $sent devices');
      },
      failure: (f) => AppToast.failure(context, f),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return AdminGate(
      title: l.adminBroadcast,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.lg),
          children: [
            TextFormField(
              controller: _title,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => Validators.minLength(v, 3),
            ),
            TextFormField(
              controller: _body,
              maxLines: 3,
              maxLength: 180,
              decoration: const InputDecoration(labelText: 'Message'),
              validator: (v) => Validators.minLength(v, 5),
            ),
            const SizedBox(height: AppDimens.lg),
            DropdownButtonFormField<String>(
              initialValue: _audience,
              decoration: const InputDecoration(labelText: 'Audience'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Everyone')),
                DropdownMenuItem(value: 'vip', child: Text('VIP members')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: (v) => setState(() => _audience = v ?? 'all'),
            ),
            const SizedBox(height: AppDimens.lg),
            DropdownButtonFormField<String>(
              initialValue: _deeplink.isEmpty ? null : _deeplink,
              decoration: const InputDecoration(
                labelText: 'Open on tap (optional)',
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Nothing')),
                DropdownMenuItem(value: Routes.earn, child: Text('Earn')),
                DropdownMenuItem(value: Routes.tasks, child: Text('Offers')),
                DropdownMenuItem(value: Routes.rewards, child: Text('Rewards')),
                DropdownMenuItem(value: Routes.vip, child: Text('VIP')),
              ],
              onChanged: (v) => setState(() => _deeplink = v ?? ''),
            ),
            const SizedBox(height: AppDimens.xl),
            GradientButton(
              label: 'Send',
              icon: Icons.campaign,
              enabled: !_busy,
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }
}
