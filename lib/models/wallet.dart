import 'package:equatable/equatable.dart';

import 'parse.dart';

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
    this.pendingRedemptionCoins = 0,
    this.updatedAt,
  });

  const Wallet.empty(this.uid)
      : balance = 0,
        lifetimeEarned = 0,
        lifetimeSpent = 0,
        pendingRedemptionCoins = 0,
        updatedAt = null;

  factory Wallet.fromMap(String uid, Map<String, dynamic> map) => Wallet(
        uid: uid,
        balance: Parse.toInt(map['balance']),
        lifetimeEarned: Parse.toInt(map['lifetimeEarned']),
        lifetimeSpent: Parse.toInt(map['lifetimeSpent']),
        pendingRedemptionCoins: Parse.toInt(map['pendingRedemptionCoins']),
        updatedAt: Parse.toDate(map['updatedAt']),
      );

  final String uid;

  /// Coins the user can spend right now. Coins locked in a pending redemption
  /// have already been subtracted from this, so it never needs adjusting for
  /// [pendingRedemptionCoins] at the call site.
  final int balance;
  final int lifetimeEarned;
  final int lifetimeSpent;

  /// Coins held by redemptions awaiting fulfilment. Shown to the user so a
  /// balance that dropped after a withdrawal request doesn't look like a loss.
  final int pendingRedemptionCoins;
  final DateTime? updatedAt;

  bool canAfford(int coins) => balance >= coins;

  @override
  List<Object?> get props =>
      [uid, balance, lifetimeEarned, lifetimeSpent, pendingRedemptionCoins];
}
