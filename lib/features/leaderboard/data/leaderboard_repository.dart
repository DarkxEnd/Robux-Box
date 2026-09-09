import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../models/leaderboard_entry.dart';

/// Reads the pre-built leaderboards.
///
/// Never computed on the fly: ranking every user would mean reading every
/// wallet, which no client may do. The scheduled `aggregateLeaderboards` job
/// writes these documents, so a read here is one small ordered query.
class LeaderboardRepository {
  const LeaderboardRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<LeaderboardEntry>> watch(
    LeaderboardPeriod period, {
    int limit = AppConstants.leaderboardPageSize,
  }) => _db
      .collection(FsPaths.leaderboards)
      .doc(period.wire)
      .collection(FsPaths.leaderboardEntries)
      .orderBy('rank')
      .limit(limit)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => LeaderboardEntry.fromMap(d.id, d.data()))
            .toList(),
      );

  /// The signed-in user's own row, which is usually outside the top N.
  Stream<LeaderboardEntry?> watchMine(LeaderboardPeriod period, String uid) =>
      _db
          .collection(FsPaths.leaderboards)
          .doc(period.wire)
          .collection(FsPaths.leaderboardEntries)
          .doc(uid)
          .snapshots()
          .map(
            (s) => s.exists ? LeaderboardEntry.fromMap(uid, s.data()!) : null,
          );
}

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepository(ref.watch(firestoreProvider));
});

final selectedPeriodProvider = StateProvider<LeaderboardPeriod>(
  (ref) => LeaderboardPeriod.weekly,
);

final leaderboardProvider = StreamProvider<List<LeaderboardEntry>>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref.watch(leaderboardRepositoryProvider).watch(period);
});

final myRankProvider = StreamProvider<LeaderboardEntry?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  final period = ref.watch(selectedPeriodProvider);
  return ref.watch(leaderboardRepositoryProvider).watchMine(period, uid);
});
