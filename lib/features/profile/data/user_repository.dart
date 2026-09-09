import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/network/firebase_error_mapper.dart';
import '../../../models/app_user.dart';

/// Reads and edits the user's own profile document.
///
/// Only a narrow set of cosmetic fields is writable from here; `firestore.rules`
/// rejects any write touching `vipLevel`, `isAdmin`, `status`, `xp`,
/// `countryCode` or anything else that decides what the user is owed.
class UserRepository {
  const UserRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(FsPaths.users).doc(uid);

  Stream<AppUser?> watch(String uid) => _doc(uid).snapshots().map(
    (snap) => snap.exists ? AppUser.fromMap(uid, snap.data()!) : null,
  );

  Future<Result<AppUser>> load(String uid) async {
    try {
      final snap = await _doc(uid).get();
      if (!snap.exists) {
        return const Result.failure(OperationFailureNotFound());
      }
      return Result.success(AppUser.fromMap(uid, snap.data()!));
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  /// The fields a user may change about themselves.
  Future<Result<void>> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    String? robloxUsername,
  }) async {
    try {
      final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
      if (displayName != null) data['displayName'] = displayName.trim();
      if (photoUrl != null) data['photoUrl'] = photoUrl;
      if (robloxUsername != null) {
        data['robloxUsername'] = robloxUsername.trim();
      }

      await _doc(uid).set(data, SetOptions(merge: true));

      // Mirror the name onto the Auth record so it also appears on the
      // leaderboard snapshot the server builds.
      if (displayName != null) {
        await _auth.currentUser?.updateDisplayName(displayName.trim());
      }
      return const Result.success(null);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  /// Stores the FCM token so the server can push to this device.
  ///
  /// Tokens live in an array because one account can legitimately have several
  /// devices; the server prunes entries that FCM reports as unregistered.
  Future<void> registerPushToken(String uid, String token) async {
    try {
      await _doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Push registration is never worth failing a screen over.
    }
  }
}

/// Returned when the profile document is missing, which in practice means the
/// `onUserCreate` trigger has not finished yet on a brand-new account.
class OperationFailureNotFound extends OperationFailure {
  const OperationFailureNotFound()
    : super(
        'Setting up your account… pull to refresh in a moment.',
        code: 'profile-not-ready',
      );
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

/// The signed-in user's profile, live. Null while signed out.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watch(uid);
});
