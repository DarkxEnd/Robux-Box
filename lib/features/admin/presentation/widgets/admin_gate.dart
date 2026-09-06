import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/providers.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/state_views.dart';

/// Wraps every admin screen.
///
/// The claim is re-checked here rather than trusted from the route: the route
/// being reachable is not authorisation, and a deeplink or a stale build could
/// land a non-admin on one of these screens. This is defence in depth only —
/// the real enforcement is in `firestore.rules` and `requireAdmin` on every
/// admin callable, both of which reject a non-admin regardless of what the UI
/// allows.
class AdminGate extends ConsumerWidget {
  const AdminGate({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    return isAdmin.when(
      loading: () => const AppScaffold(body: LoadingView()),
      error: (_, __) => const AppScaffold(
        body: EmptyView(
          icon: Icons.lock_outline,
          title: 'Could not verify your access.',
        ),
      ),
      data: (allowed) {
        if (!allowed) {
          return const AppScaffold(
            body: EmptyView(
              icon: Icons.block_outlined,
              title: 'Admins only.',
            ),
          );
        }
        return AppScaffold(title: title, body: child);
      },
    );
  }
}
