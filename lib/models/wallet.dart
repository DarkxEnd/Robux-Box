import 'package:equatable/equatable.dart';

import 'model_utils.dart';

/// The coin balance (`wallets/{uid}`).
///
/// Deliberately a separate document from the user profile: `firestore.rules`
/// makes this collection read-only to clients, so only Cloud Functions running
/// with the Admin SDK can move coins. Never write to it from the app.
class Wallet extends Equatable {
  const Wallet({
    required this.uid,
    this.balance = 0,
    this.lifetimeEarned = 0,
    this.lifetimeSpent = 0,
    this.updatedAt,
  });

  const Wallet.empty(this.uid)
    : balance = 0,
      lifetimeEarned = 0,
      lifetimeSpent = 0,
      updatedAt = null;

  /// The stored field is `coins`, not `balance` — verified against both
  /// functions/src/lib/wallet.ts and the shipped bundle. Reading `balance`
  /// here silently shows every user a zero balance, which is exactly the bug
  /// this comment exists to prevent recurring.
  factory Wallet.fromMap(String uid, Map<String, dynamic> map) => Wallet(
    uid: uid,
    balance: Parse.toInt(map['coins']),
    lifetimeEarned: Parse.toInt(map['lifetimeEarned']),
    lifetimeSpent: Parse.toInt(map['lifetimeSpent']),
    updatedAt: Parse.toDate(map['updatedAt']),
  );

  final String uid;

  /// Coins the user can spend right now.
  ///
  /// A redemption request debits this immediately — the server holds the coins
  /// by taking them, not by flagging them — so a pending withdrawal is already
  /// excluded here. See `pendingRedemptionCoinsProvider` for what is on hold.
  final int balance;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final DateTime? updatedAt;

  bool canAfford(int coins) => balance >= coins;

  @override
  List<Object?> get props => [uid, balance, lifetimeEarned, lifetimeSpent];
}
