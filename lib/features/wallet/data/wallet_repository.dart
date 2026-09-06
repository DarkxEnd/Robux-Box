import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/error/result.dart';
import '../../../core/network/firebase_error_mapper.dart';
import '../../../core/services/callable_service.dart';
import '../../../models/transaction.dart';
import '../../../models/wallet.dart';

/// Reads the wallet and its transaction history.
///
/// Strictly read-only. `firestore.rules` blocks every client write to
/// `wallets` and `transactions`; the only way coins move is through a Cloud
/// Function running with the Admin SDK. If you find yourself wanting a write
/// method here, the logic belongs on the server instead.
class WalletRepository {
  const WalletRepository(this._db, this._callables);

  final FirebaseFirestore _db;
  final CallableService _callables;

  Stream<Wallet> watch(String uid) => _db
      .collection(FsPaths.wallets)
      .doc(uid)
      .snapshots()
      // A missing wallet is a new account whose trigger has not run yet, not
      // an error — showing zero is correct and lets the UI render.
      .map(
        (s) => s.exists ? Wallet.fromMap(uid, s.data()!) : Wallet.empty(uid),
      );

  /// Transaction history, newest first.
  ///
  /// Needs the composite index on (uid, createdAt desc) declared in
  /// firestore.indexes.json.
  Stream<List<AppTransaction>> watchTransactions(
    String uid, {
    int limit = AppConstants.transactionsPageSize,
  }) => _db
      .collection(FsPaths.transactions)
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => AppTransaction.fromMap(d.id, d.data()))
            .toList(),
      );

  /// Older pages, keyed on the last document already shown.
  Future<Result<List<AppTransaction>>> loadMore({
    required String uid,
    required DateTime before,
    int limit = AppConstants.transactionsPageSize,
  }) async {
    try {
      final snap = await _db
          .collection(FsPaths.transactions)
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .startAfter([Timestamp.fromDate(before)])
          .limit(limit)
          .get();
      return Result.success(
        snap.docs.map((d) => AppTransaction.fromMap(d.id, d.data())).toList(),
      );
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  /// Server-side fallback for the history.
  ///
  /// Used when the direct query is refused — a rules change or a missing index
  /// makes the collection unreadable, and the callable still works because it
  /// runs with admin privileges.
  Future<Result<List<AppTransaction>>> recentViaCallable({
    int limit = 25,
  }) async {
    final res = await _callables.call('recentTransactions', {'limit': limit});
    return res.map((data) {
      final items = data['transactions'] as List<dynamic>? ?? const [];
      return items.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return AppTransaction.fromMap((map['id'] as String?) ?? '', map);
      }).toList();
    });
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    ref.watch(firestoreProvider),
    ref.watch(callableServiceProvider),
  );
});

/// The signed-in user's wallet, live.
final walletProvider = StreamProvider<Wallet>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const Wallet.empty(''));
  return ref.watch(walletRepositoryProvider).watch(uid);
});

/// Just the balance, so a widget showing only the number does not rebuild when
/// an unrelated wallet field changes.
final balanceProvider = Provider<int>((ref) {
  return ref.watch(walletProvider).valueOrNull?.balance ?? 0;
});

final transactionsProvider = StreamProvider<List<AppTransaction>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(walletRepositoryProvider).watchTransactions(uid);
});
