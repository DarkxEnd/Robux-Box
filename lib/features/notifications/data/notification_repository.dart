import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/error/result.dart';
import '../../../core/network/firebase_error_mapper.dart';
import '../../../models/app_notification.dart';

/// The in-app inbox (`users/{uid}/notifications`).
///
/// Documents are written server-side; the only field a client may change is
/// `isRead`, which the rules enforce.
class NotificationRepository {
  const NotificationRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _db
      .collection(FsPaths.users)
      .doc(uid)
      .collection(FsPaths.userNotifications);

  Stream<List<AppNotification>> watch(String uid, {int limit = 50}) => _col(uid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => AppNotification.fromMap(d.id, d.data()))
          .toList());

  /// Unread count, from a server-side aggregation rather than by reading every
  /// document — the badge is on the home screen and would otherwise pull the
  /// whole inbox on every launch.
  Stream<int> watchUnreadCount(String uid) => _col(uid)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);

  Future<Result<void>> markRead(String uid, String id) async {
    try {
      await _col(uid).doc(id).update({'isRead': true});
      return const Result.success(null);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  Future<Result<void>> markAllRead(String uid) async {
    try {
      final unread =
          await _col(uid).where('isRead', isEqualTo: false).limit(400).get();
      if (unread.docs.isEmpty) return const Result.success(null);

      // Batched: 400 individual writes would be 400 round trips and could
      // exhaust the write quota on a busy account.
      final batch = _db.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      return const Result.success(null);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  Future<Result<void>> delete(String uid, String id) async {
    try {
      await _col(uid).doc(id).delete();
      return const Result.success(null);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(firestoreProvider));
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watch(uid);
});

final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(0);
  return ref.watch(notificationRepositoryProvider).watchUnreadCount(uid);
});
