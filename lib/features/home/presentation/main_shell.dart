import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/providers.dart';
import '../../profile/data/user_repository.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/connectivity_banner.dart';

/// The five-tab frame around the main screens.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame: notification setup touches platform
    // channels, and doing it during build stalls the first paint.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initNotifications());
  }

  Future<void> _initNotifications() async {
    final notifications = ref.read(notificationServiceProvider);
    notifications.onDeeplink = _handleDeeplink;
    await notifications.initialise();

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    final token = await notifications.token();
    if (token != null) {
      await ref.read(userRepositoryProvider).registerPushToken(uid, token);
    }

    // FCM rotates tokens on reinstall and occasionally on its own; without
    // this, pushes stop arriving with no visible cause.
    notifications.tokenRefresh.listen((fresh) {
      final current = ref.read(currentUidProvider);
      if (current != null) {
        ref.read(userRepositoryProvider).registerPushToken(current, fresh);
      }
    });
  }

  /// Only navigates to routes the app actually declares. A push payload is
  /// attacker-influenced in principle, so an unknown path is dropped.
  void _handleDeeplink(String route) {
    if (!mounted || !Routes.isKnown(route)) return;
    context.go(route);
  }

  int _indexOf(String location) {
    final i = Routes.shellTabs.indexWhere(
      (tab) => location == tab || location.startsWith('$tab/'),
    );
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexOf(location);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const ConnectivityBanner(),
              Expanded(child: widget.child),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          height: AppDimens.navBarHeight,
          selectedIndex: index,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) {
            // go() rather than push(): tapping a tab should replace, not stack,
            // or back would walk through every tab the user visited.
            if (i != index) context.go(Routes.shellTabs[i]);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: l.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.play_circle_outline),
              selectedIcon: const Icon(Icons.play_circle_rounded),
              label: l.navEarn,
            ),
            NavigationDestination(
              icon: const Icon(Icons.task_alt_outlined),
              selectedIcon: const Icon(Icons.task_alt_rounded),
              label: l.navTasks,
            ),
            NavigationDestination(
              icon: const Icon(Icons.card_giftcard_outlined),
              selectedIcon: const Icon(Icons.card_giftcard_rounded),
              label: l.navRewards,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person_rounded),
              label: l.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}
