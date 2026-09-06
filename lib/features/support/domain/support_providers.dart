import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../models/support_ticket.dart';
import '../data/support_repository.dart';

final ticketCategoriesProvider = StreamProvider<List<TicketCategory>>((ref) {
  return ref.watch(supportRepositoryProvider).watchCategories();
});

final myTicketsProvider = StreamProvider<List<SupportTicket>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(supportRepositoryProvider).watchMine(uid);
});
