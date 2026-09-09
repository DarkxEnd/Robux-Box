import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/promocode.dart';
import '../../../models/redemption.dart';
import '../../../models/reward.dart';
import '../../../models/support_ticket.dart';
import '../data/admin_repository.dart';

/// Which redemption status the admin list is filtered to. Null means all.
final redemptionFilterProvider = StateProvider<String?>((ref) => 'pending');

final adminRedemptionsProvider = StreamProvider<List<Redemption>>((ref) {
  final status = ref.watch(redemptionFilterProvider);
  return ref.watch(adminRepositoryProvider).watchRedemptions(status: status);
});

final adminRewardsProvider = StreamProvider<List<Reward>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllRewards();
});

final adminPromocodesProvider = StreamProvider<List<PromoCode>>((ref) {
  return ref.watch(adminRepositoryProvider).watchPromocodes();
});

final ticketFilterProvider = StateProvider<String?>((ref) => 'open');

final adminTicketsProvider = StreamProvider<List<SupportTicket>>((ref) {
  final status = ref.watch(ticketFilterProvider);
  return ref.watch(adminRepositoryProvider).watchTickets(status: status);
});

final adminReportsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchReports();
});

final adminVipPurchasesProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(adminRepositoryProvider).watchVipPurchases();
});

/// One page of users, plus the cursor for the next.
final adminUsersProvider = FutureProvider<(List<AdminUser>, String?)>((
  ref,
) async {
  final res = await ref.watch(adminRepositoryProvider).listUsers();
  return res.valueOrNull ?? (const <AdminUser>[], null);
});

final adminAnalyticsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final res = await ref.watch(adminRepositoryProvider).refreshAnalytics();
  return res.valueOrNull ?? const {};
});
