import 'package:equatable/equatable.dart';

import 'model_utils.dart';

/// A promo code (`promocodes/{CODE}`), redeemed through the `redeemPromocode`
/// callable.
///
/// Clients cannot read this collection — the rules block it. The model exists
/// for the admin dashboard, which reads it with an admin claim, and for
/// rendering what the callable returns. Nothing here is used to decide whether
/// a redemption is allowed; that is entirely server-side, including the
/// per-user limit, which needs a subcollection the client never sees.
class PromoCode extends Equatable {
  const PromoCode({
    required this.code,
    required this.rewardCoins,
    this.maxRedemptions = -1,
    this.perUserLimit = 1,
    this.redemptionCount = 0,
    this.isActive = true,
    this.expiresAt,
    this.createdAt,
  });

  factory PromoCode.fromMap(String code, Map<String, dynamic> map) => PromoCode(
        code: code,
        rewardCoins: Parse.toInt(map['rewardCoins']),
        maxRedemptions: Parse.toInt(map['maxRedemptions'], -1),
        perUserLimit: Parse.toInt(map['perUserLimit'], 1),
        redemptionCount: Parse.toInt(map['redemptionCount']),
        isActive: Parse.toBool(map['isActive'], true),
        expiresAt: Parse.toDate(map['expiresAt']),
        createdAt: Parse.toDate(map['createdAt']),
      );

  final String code;
  final int rewardCoins;

  /// Total redemptions allowed across all users, or `-1` for unlimited.
  final int maxRedemptions;
  final int perUserLimit;
  final int redemptionCount;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isExhausted =>
      maxRedemptions >= 0 && redemptionCount >= maxRedemptions;

  /// Admin-dashboard display only. The callable makes this decision itself.
  bool get isUsable => isActive && !isExpired && !isExhausted;

  int get remaining =>
      maxRedemptions < 0 ? -1 : (maxRedemptions - redemptionCount).clamp(0, maxRedemptions);

  Map<String, dynamic> toMap() => {
        'rewardCoins': rewardCoins,
        'maxRedemptions': maxRedemptions,
        'perUserLimit': perUserLimit,
        'isActive': isActive,
        'expiresAt': expiresAt,
      };

  @override
  List<Object?> get props =>
      [code, rewardCoins, maxRedemptions, redemptionCount, isActive, expiresAt];
}
