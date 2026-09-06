import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/state_views.dart';
import '../data/admin_repository.dart';
import '../domain/admin_providers.dart';
import 'widgets/admin_gate.dart';

/// Grants and revokes the admin claim.
///
/// The most dangerous screen in the app: the claim it sets is what
/// `firestore.rules` and every admin callable trust. Granting it hands over
/// the ability to mint coins, so both directions require confirmation and a
/// self-revoke is blocked outright — locking the last admin out of their own
/// dashboard is not recoverable from inside the app.
class AdminManageAdminsScreen extends ConsumerWidget {
  const AdminManageAdminsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final page = ref.watch(adminUsersProvider);
    final selfUid = ref.watch(currentUidProvider);

    return AdminGate(
      title: l.adminManageAdmins,
      child: AsyncView(
        value: page,
        onRetry: () => ref.invalidate(adminUsersProvider),
        data: (result) {
          final (users, _) = result;
          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.lg),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimens.sm),
            itemBuilder: (_, i) {
              final user = users[i];
              final isSelf = user.uid == selfUid;

              return GlassCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.email ?? user.displayName ?? user.uid,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            isSelf ? 'You' : user.uid,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: user.isAdmin,
                      // Revoking your own claim would lock you out with no way
                      // back through the UI.
                      onChanged: isSelf && user.isAdmin
                          ? null
                          : (v) => _confirm(context, ref, user.uid, v),
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

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    String uid,
    bool grant,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(grant ? 'Grant admin?' : 'Revoke admin?'),
        content: Text(
          grant
              ? 'This user will be able to adjust balances, process '
                  'redemptions and send broadcasts.'
              : 'This user will lose all admin access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(grant ? 'Grant' : 'Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(adminRepositoryProvider)
        .setAdminClaim(uid: uid, admin: grant);
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(adminUsersProvider);
        AppToast.success(context, grant ? 'Granted' : 'Revoked');
      },
      failure: (f) => AppToast.failure(context, f),
    );
  }
}
