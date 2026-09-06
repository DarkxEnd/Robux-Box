import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/error/result.dart';
import '../../../core/network/firebase_error_mapper.dart';
import '../../../core/services/callable_service.dart';
import '../../../models/promocode.dart';
import '../../../models/redemption.dart';
import '../../../models/reward.dart';
import '../../../models/support_ticket.dart';

/// A user row in the admin list.
class AdminUser {
  const AdminUser({
    required this.uid,
    required this.coins,
    this.email,
    this.displayName,
    this.countryCode,
    this.vipLevel = 'none',
    this.status = 'active',
    this.isAdmin = false,
  });

  factory AdminUser.fromMap(Map<String, dynamic> map) => AdminUser(
    uid: (map['uid'] as String?) ?? '',
    // The callable reads the wallet's `coins` field and returns it under
    // the same name — not `balance`.
    coins: (map['coins'] as num?)?.toInt() ?? 0,
    email: map['email'] as String?,
    displayName: map['displayName'] as String?,
    countryCode: map['countryCode'] as String?,
    vipLevel: (map['vipLevel'] as String?) ?? 'none',
    status: (map['status'] as String?) ?? 'active',
    isAdmin: map['isAdmin'] == true,
  );

  final String uid;
  final int coins;
  final String? email;
  final String? displayName;
  final String? countryCode;
  final String vipLevel;
  final String status;
  final bool isAdmin;
}

/// Every privileged operation.
///
/// All of it goes through callables, never direct writes: the rules deny
/// client writes to these collections outright, and the callables additionally
/// verify the admin claim and write an audit entry. An admin acting through
/// the app leaves the same trail as one acting through a script.
class AdminRepository {
  const AdminRepository(this._db, this._callables);

  final FirebaseFirestore _db;
  final CallableService _callables;

  // --- Users -------------------------------------------------------------

  Future<Result<(List<AdminUser>, String?)>> listUsers({
    int limit = 25,
    String? startAfter,
  }) async {
    final res = await _callables.call('listUsers', {
      'limit': limit,
      if (startAfter != null) 'startAfter': startAfter,
    });
    return res.map((data) {
      final items = (data['items'] as List<dynamic>? ?? const [])
          .map((e) => AdminUser.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      return (items, data['nextCursor'] as String?);
    });
  }

  Future<Result<void>> adjustCoins({
    required String uid,
    required int amount,
    required String reason,
  }) async {
    final res = await _callables.call('adjustCoins', {
      'uid': uid,
      'amount': amount,
      'reason': reason,
    });
    return res.map((_) {});
  }

  Future<Result<void>> setAccountStatus({
    required String uid,
    required String status,
    String reason = '',
  }) async {
    final res = await _callables.call('setAccountStatus', {
      'uid': uid,
      'status': status,
      'reason': reason,
    });
    return res.map((_) {});
  }

  Future<Result<void>> setVipLevel({
    required String uid,
    required String level,
  }) async {
    final res = await _callables.call('setVipLevel', {
      'uid': uid,
      'level': level,
    });
    return res.map((_) {});
  }

  Future<Result<void>> setUserLevel({
    required String uid,
    required int level,
  }) async {
    final res = await _callables.call('setUserLevel', {
      'uid': uid,
      'level': level,
    });
    return res.map((_) {});
  }

  Future<Result<void>> setAdminClaim({
    required String uid,
    required bool admin,
  }) async {
    final res = await _callables.call('setAdminClaim', {
      'uid': uid,
      'admin': admin,
    });
    return res.map((_) {});
  }

  // --- Redemptions -------------------------------------------------------

  /// Pending first, then by age. Needs the (status, createdAt) index.
  Stream<List<Redemption>> watchRedemptions({String? status}) {
    Query<Map<String, dynamic>> q = _db.collection(FsPaths.redemptions);
    if (status != null) q = q.where('status', isEqualTo: status);
    return q
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Redemption.fromMap(d.id, d.data())).toList(),
        );
  }

  /// [status] is `processing`, `completed` or `rejected`. Rejecting refunds.
  Future<Result<void>> processRedemption({
    required String id,
    required String status,
    String note = '',
  }) async {
    final res = await _callables.call('processRedemption', {
      'id': id,
      'status': status,
      'note': note,
    });
    return res.map((_) {});
  }

  Future<Result<bool>> deleteRedemption(String id) async {
    final res = await _callables.call('deleteRedemption', {'id': id});
    return res.map((data) => data['refunded'] == true);
  }

  // --- Catalogue ---------------------------------------------------------

  Stream<List<Reward>> watchAllRewards() => _db
      .collection(FsPaths.rewards)
      .orderBy('sortOrder')
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => Reward.fromMap(d.id, d.data())).toList(),
      );

  Future<Result<void>> upsertReward(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      await _db
          .collection(FsPaths.rewards)
          .doc(id)
          .set(data, SetOptions(merge: true));
      return const Result.success(null);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  // --- Promo codes -------------------------------------------------------

  Stream<List<PromoCode>> watchPromocodes() => _db
      .collection(FsPaths.promocodes)
      .limit(100)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => PromoCode.fromMap(d.id, d.data())).toList(),
      );

  Future<Result<void>> upsertPromocode({
    required String code,
    required int rewardCoins,
    int maxRedemptions = -1,
    int perUserLimit = 1,
    bool isActive = true,
    DateTime? expiresAt,
  }) async {
    final res = await _callables.call('upsertPromocode', {
      'code': code,
      'rewardCoins': rewardCoins,
      'maxRedemptions': maxRedemptions,
      'perUserLimit': perUserLimit,
      'isActive': isActive,
      'expiresAt': expiresAt?.millisecondsSinceEpoch ?? 0,
    });
    return res.map((_) {});
  }

  // --- Broadcast / analytics --------------------------------------------

  Future<Result<int>> broadcast({
    required String title,
    required String body,
    String audience = 'all',
    String deeplink = '',
  }) async {
    final res = await _callables.call('broadcastNotification', {
      'title': title,
      'body': body,
      'audience': audience,
      'deeplink': deeplink,
    });
    return res.map((data) => (data['sent'] as num?)?.toInt() ?? 0);
  }

  Future<Result<Map<String, dynamic>>> refreshAnalytics() =>
      _callables.call('refreshAnalytics');

  // --- Tickets / reports -------------------------------------------------

  Stream<List<SupportTicket>> watchTickets({String? status}) {
    Query<Map<String, dynamic>> q = _db.collection(FsPaths.supportTickets);
    if (status != null) q = q.where('status', isEqualTo: status);
    return q
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SupportTicket.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  /// Replies as support. `fromAdmin: true` is only writable with the claim.
  Future<Result<void>> replyToTicket({
    required String ticketId,
    required String body,
    required String authorName,
  }) async {
    try {
      await _db.collection(FsPaths.supportTickets).doc(ticketId).update({
        'messages': FieldValue.arrayUnion([
          {
            'body': body.trim(),
            'fromAdmin': true,
            'authorName': authorName,
            'sentAt': Timestamp.now(),
          },
        ]),
        'status': 'awaiting_user',
        'hasUnreadForUser': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Result.success(null);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  Future<Result<void>> setTicketStatus(String id, String status) async {
    try {
      await _db.collection(FsPaths.supportTickets).doc(id).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Result.success(null);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  Stream<List<Map<String, dynamic>>> watchReports() => _db
      .collection(FsPaths.reports)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Stream<List<Map<String, dynamic>>> watchVipPurchases() => _db
      .collection(FsPaths.vipPurchases)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(
    ref.watch(firestoreProvider),
    ref.watch(callableServiceProvider),
  );
});
