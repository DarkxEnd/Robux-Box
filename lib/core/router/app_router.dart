import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/achievements/presentation/achievements_screen.dart';
import '../../features/admin/presentation/admin_analytics_screen.dart';
import '../../features/admin/presentation/admin_broadcast_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_manage_admins_screen.dart';
import '../../features/admin/presentation/admin_promocodes_screen.dart';
import '../../features/admin/presentation/admin_redemptions_screen.dart';
import '../../features/admin/presentation/admin_reports_screen.dart';
import '../../features/admin/presentation/admin_rewards_screen.dart';
import '../../features/admin/presentation/admin_tickets_screen.dart';
import '../../features/admin/presentation/admin_users_screen.dart';
import '../../features/admin/presentation/admin_vip_purchases_screen.dart';
import '../../features/auth/presentation/email_auth_screen.dart';
import '../../features/auth/presentation/location_gate_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/phone_auth_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/earn/presentation/earn_screen.dart';
import '../../features/earn/presentation/offerwall_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/main_shell.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/redemption/presentation/redemptions_screen.dart';
import '../../features/redemption/presentation/rewards_screen.dart';
import '../../features/referrals/presentation/referrals_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/support/presentation/support_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/vip/presentation/vip_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../models/offerwall.dart';
import '../config/providers.dart';
import 'splash_screen.dart';

/// Every route path in the app.
///
/// These strings are recovered from the shipped bundle and are load-bearing:
/// server-sent notifications carry them as deeplinks, so a path renamed here
/// silently breaks every push already queued for delivery.
abstract final class Routes {
  const Routes._();

  static const splash = '/';
  static const welcome = '/welcome';
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const authEmail = '/auth/email';
  static const authPhone = '/auth/phone';
  static const locationRequired = '/location-required';

  static const home = '/home';
  static const earn = '/earn';
  static const offerwall = '/earn/offerwall';
  static const offerwallCpalead = '/earn/offerwall/cpalead';
  static const offerwallLootwalls = '/earn/offerwall/lootwalls';
  static const tasks = '/tasks';
  static const rewards = '/rewards';
  static const redemptions = '/redemptions';
  static const wallet = '/wallet';
  static const profile = '/profile';

  static const settings = '/settings';
  static const support = '/support';
  static const notifications = '/notifications';
  static const messages = '/messages';
  static const leaderboard = '/leaderboard';
  static const achievements = '/achievements';
  static const referrals = '/referrals';
  static const vip = '/vip';

  static const admin = '/admin';
  static const adminUsers = '/admin/users';
  static const adminRedemptions = '/admin/redemptions';
  static const adminRewards = '/admin/rewards';
  static const adminPromocodes = '/admin/promocodes';
  static const adminBroadcast = '/admin/broadcast';
  static const adminAnalytics = '/admin/analytics';
  static const adminTickets = '/admin/tickets';
  static const adminReports = '/admin/reports';
  static const adminVipPurchases = '/admin/vip-purchases';
  static const adminAdmins = '/admin/admins';

  /// The five tabs of the bottom navigation bar, in order.
  static const shellTabs = [home, earn, tasks, rewards, profile];

  /// Whether a string from a push payload is a route this app actually has.
  /// Anything else is ignored rather than navigated to.
  static bool isKnown(String path) =>
      _all.contains(path) || _all.any((r) => path.startsWith('$r/'));

  static const _all = {
    splash, welcome, onboarding, auth, authEmail, authPhone, locationRequired,
    home, earn, offerwall, offerwallCpalead, offerwallLootwalls, tasks,
    rewards, redemptions, wallet, profile, settings, support, notifications,
    messages, leaderboard, achievements, referrals, vip, admin, adminUsers,
    adminRedemptions, adminRewards, adminPromocodes, adminBroadcast,
    adminAnalytics, adminTickets, adminReports, adminVipPurchases, adminAdmins,
  };
}

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

/// Navigator key for showing dialogs from outside the widget tree (a push tap
/// arriving while no route is focused).
GlobalKey<NavigatorState> get rootNavigatorKey => _rootKey;

final routerProvider = Provider<GoRouter>((ref) {
  // Watching auth here rebuilds the router on sign-in/sign-out, which is what
  // makes the redirect below re-run.
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    debugLogDiagnostics: false,

    redirect: (context, state) {
      final loggingIn = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation == Routes.welcome ||
          state.matchedLocation == Routes.onboarding;

      // Hold on the splash until Firebase has actually resolved the session.
      // Redirecting on a null-because-still-loading user would bounce a
      // returning user out to the welcome screen on every cold start.
      if (auth.isLoading) return null;

      final signedIn = auth.valueOrNull != null;
      if (!signedIn) return loggingIn ? null : Routes.welcome;
      if (loggingIn || state.matchedLocation == Routes.splash) {
        return Routes.home;
      }
      return null;
    },

    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),

      // Auth flow — outside the shell, so no navigation bar.
      GoRoute(path: Routes.welcome, builder: (_, __) => const WelcomeScreen()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.auth,
        redirect: (_, __) => Routes.welcome,
      ),
      GoRoute(
        path: Routes.authEmail,
        builder: (_, __) => const EmailAuthScreen(),
      ),
      GoRoute(
        path: Routes.authPhone,
        builder: (_, __) => const PhoneAuthScreen(),
      ),
      GoRoute(
        path: Routes.locationRequired,
        builder: (_, __) => const LocationGateScreen(),
      ),

      // The five tabs live in a shell so the nav bar does not rebuild — and
      // more importantly so tab state survives switching.
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
          GoRoute(path: Routes.earn, builder: (_, __) => const EarnScreen()),
          GoRoute(path: Routes.tasks, builder: (_, __) => const TasksScreen()),
          GoRoute(
            path: Routes.rewards,
            builder: (_, __) => const RewardsScreen(),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),

      // Offerwalls are full-screen WebViews pushed above the shell: the nav
      // bar must not overlay a third-party page, and covering it stops the
      // user losing their place in a survey by mistapping a tab.
      GoRoute(
        path: Routes.offerwall,
        parentNavigatorKey: _rootKey,
        builder: (_, __) =>
            const OfferwallScreen(provider: OfferwallProvider.cpx),
      ),
      GoRoute(
        path: Routes.offerwallCpalead,
        parentNavigatorKey: _rootKey,
        builder: (_, __) =>
            const OfferwallScreen(provider: OfferwallProvider.cpalead),
      ),
      GoRoute(
        path: Routes.offerwallLootwalls,
        parentNavigatorKey: _rootKey,
        builder: (_, __) =>
            const OfferwallScreen(provider: OfferwallProvider.lootwalls),
      ),

      GoRoute(path: Routes.wallet, builder: (_, __) => const WalletScreen()),
      GoRoute(
        path: Routes.redemptions,
        builder: (_, __) => const RedemptionsScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(path: Routes.support, builder: (_, __) => const SupportScreen()),
      GoRoute(
        path: Routes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      // `/messages` is an older deeplink for the same screen; kept so pushes
      // already sent with it still land somewhere sensible.
      GoRoute(
        path: Routes.messages,
        redirect: (_, __) => Routes.notifications,
      ),
      GoRoute(
        path: Routes.leaderboard,
        builder: (_, __) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: Routes.achievements,
        builder: (_, __) => const AchievementsScreen(),
      ),
      GoRoute(
        path: Routes.referrals,
        builder: (_, __) => const ReferralsScreen(),
      ),
      GoRoute(path: Routes.vip, builder: (_, __) => const VipScreen()),

      // Admin. Every screen is additionally wrapped in AdminGate, which
      // re-checks the claim — the route being reachable is never the
      // authorisation.
      GoRoute(
        path: Routes.admin,
        builder: (_, __) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: Routes.adminUsers,
        builder: (_, __) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: Routes.adminRedemptions,
        builder: (_, __) => const AdminRedemptionsScreen(),
      ),
      GoRoute(
        path: Routes.adminRewards,
        builder: (_, __) => const AdminRewardsScreen(),
      ),
      GoRoute(
        path: Routes.adminPromocodes,
        builder: (_, __) => const AdminPromocodesScreen(),
      ),
      GoRoute(
        path: Routes.adminBroadcast,
        builder: (_, __) => const AdminBroadcastScreen(),
      ),
      GoRoute(
        path: Routes.adminAnalytics,
        builder: (_, __) => const AdminAnalyticsScreen(),
      ),
      GoRoute(
        path: Routes.adminTickets,
        builder: (_, __) => const AdminTicketsScreen(),
      ),
      GoRoute(
        path: Routes.adminReports,
        builder: (_, __) => const AdminReportsScreen(),
      ),
      GoRoute(
        path: Routes.adminVipPurchases,
        builder: (_, __) => const AdminVipPurchasesScreen(),
      ),
      GoRoute(
        path: Routes.adminAdmins,
        builder: (_, __) => const AdminManageAdminsScreen(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                'That page does not exist.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(Routes.home),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
