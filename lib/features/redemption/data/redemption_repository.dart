import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/error/result.dart';
import '../../../core/services/callable_service.dart';
import '../../../models/redemption.dart';
import '../../../models/reward.dart';

/// The reward catalogue and the user's withdrawal requests.
///
/// Requests go through `requestRedemption`, never a direct write: the server
/// re-checks balance, stock, VIP tier and country, and moves the coins out of
/// the wallet in the same transaction that creates the request. A client-side
/// write could not do that atomically, so ten simultaneous taps would produce
/// ten redemptions against one balance.
class RedemptionRepository {
  const RedemptionRepository(this._db, this._callables);

  final FirebaseFirestore _db;
  final CallableService _callables;

  Stream<List<Reward>> watchRewards() => _db
      .collection(FsPaths.rewards)
      .where('isActive', isEqualTo: true)
      .orderBy('sortOrder')
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => Reward.fromMap(d.id, d.data())).toList(),
      );

  /// The user's own requests, newest first. Needs the (uid, createdAt desc)
  /// composite index.
  Stream<List<Redemption>> watchMine(String uid) => _db
      .collection(FsPaths.redemptions)
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => Redemption.fromMap(d.id, d.data())).toList(),
      );

  /// [destination] is a Roblox username for Robux rewards, an email otherwise.
  Future<Result<String>> request({
    required String rewardId,
    required String destination,
  }) async {
    final res = await _callables.call('requestRedemption', {
      'rewardId': rewardId,
      'destination': destination.trim(),
    });
    return res.map((data) => (data['id'] as String?) ?? '');
  }

  /// Cancels a pending request and refunds the coins. Only works while the
  /// status is still `pending` — once an admin starts processing, a code may
  /// already have been bought.
  Future<Result<void>> cancel(String id) async {
    final res = await _callables.call('cancelRedemption', {'id': id});
    return res.map((_) {});
  }
}

final redemptionRepositoryProvider = Provider<RedemptionRepository>((ref) {
  return RedemptionRepository(
    ref.watch(firestoreProvider),
    ref.watch(callableServiceProvider),
  );
});

final rewardsProvider = StreamProvider<List<Reward>>((ref) {
  return ref.watch(redemptionRepositoryProvider).watchRewards();
});

final myRedemptionsProvider = StreamProvider<List<Redemption>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(redemptionRepositoryProvider).watchMine(uid);
});

/// Coins currently held by unfinished withdrawal requests.
///
/// Derived rather than stored: the server holds coins by debiting the wallet
/// outright, so there is no field to read. Showing this is what stops a
/// balance that dropped after a request from looking like coins going
/// missing.
final pendingRedemptionCoinsProvider = Provider<int>((ref) {
  final list = ref.watch(myRedemptionsProvider).valueOrNull ?? const [];
  return list
      .where((r) => !r.status.isTerminal)
      .fold(0, (total, r) => total + r.coinCost);
});
