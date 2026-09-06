import 'package:equatable/equatable.dart';

import 'parse.dart';

/// Why a wallet moved. Mirrors the `type` values written by
/// `functions/src/lib/wallet.ts`; unknown values fall back to [other] rather
/// than throwing, so a new server-side type can ship before the app knows it.
enum TxType {
  rewardedAd('rewarded_ad'),
  rewardedInterstitial('rewarded_interstitial'),
  offerwall('offerwall'),
  offerwallReversal('offerwall_reversal'),
  dailyReward('daily_reward'),
  dailyStreak('daily_streak'),
  spin('spin'),
  chest('chest'),
  referralBonus('referral_bonus'),
  referralShare('referral_share'),
  achievement('achievement'),
  vipDailyBonus('vip_daily_bonus'),
  vipPurchase('vip_purchase'),
  redemption('redemption'),
  redemptionRefund('redemption_refund'),
  rateApp('rate_app'),
  adminAdjustment('admin_adjustment'),
  other('other');

  const TxType(this.wire);

  /// The exact string stored in Firestore. Changing one of these silently
  /// breaks history for every already-written document.
  final String wire;

  static TxType fromWire(String? v) => TxType.values.firstWhere(
        (t) => t.wire == v,
        orElse: () => TxType.other,
      );
}

/// One entry in `transactions/{id}` — an immutable audit record of a wallet
/// change. Clients can read their own; nobody can write them.
class AppTransaction extends Equatable {
  const AppTransaction({
    required this.id,
    required this.uid,
    required this.type,
    required this.coins,
    this.balanceAfter,
    this.description,
    this.provider,
    this.referenceId,
    this.metadata = const {},
    this.createdAt,
  });

  factory AppTransaction.fromMap(String id, Map<String, dynamic> map) =>
      AppTransaction(
        id: id,
        uid: Parse.toStr(map['uid']),
        type: TxType.fromWire(map['type'] as String?),
        coins: Parse.toInt(map['coins']),
        balanceAfter:
            map['balanceAfter'] == null ? null : Parse.toInt(map['balanceAfter']),
        description: map['description'] as String?,
        provider: map['provider'] as String?,
        referenceId: map['referenceId'] as String?,
        metadata: Parse.toMap(map['metadata']),
        createdAt: Parse.toDate(map['createdAt']),
      );

  final String id;
  final String uid;
  final TxType type;

  /// Signed: positive credits the user, negative debits. A reversal is stored
  /// as its own negative transaction rather than by deleting the original, so
  /// the history stays append-only and auditable.
  final int coins;
  final int? balanceAfter;
  final String? description;

  /// Offerwall provider (`cpx`, `cpalead`, `lootwalls`) when [type] is an
  /// offerwall credit or reversal.
  final String? provider;
  final String? referenceId;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  bool get isCredit => coins > 0;
  bool get isDebit => coins < 0;

  @override
  List<Object?> get props => [id, uid, type, coins, createdAt];
}
