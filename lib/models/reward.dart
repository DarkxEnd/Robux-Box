import 'package:equatable/equatable.dart';

import '../core/constants/app_constants.dart';
import 'parse.dart';

/// What the user actually receives. Drives which fields the redemption form
/// asks for: [robux] needs a Roblox username, the others need an email.
enum RewardKind {
  robux('robux'),
  giftCard('giftCard'),
  digitalCode('digitalCode'),
  cash('cash');

  const RewardKind(this.wire);

  final String wire;

  static RewardKind fromWire(String? v) => RewardKind.values.firstWhere(
        (k) => k.wire == v,
        orElse: () => RewardKind.giftCard,
      );
}

/// A catalogue entry (`rewards/{id}`), seeded by `scripts/seed.js` and edited
/// from the admin dashboard. Read-only to clients.
class Reward extends Equatable {
  const Reward({
    required this.id,
    required this.kind,
    required this.title,
    required this.coinCost,
    this.subtitle = '',
    this.faceValue = 0,
    this.currency = 'RBX',
    this.provider = 'manual',
    this.imageUrl = '',
    this.badge = '',
    this.isActive = true,
    this.sortOrder = 0,
    this.stock = -1,
    this.minVipLevel = 'none',
    this.allowedCountries = const [],
  });

  factory Reward.fromMap(String id, Map<String, dynamic> map) => Reward(
        id: id,
        kind: RewardKind.fromWire(map['kind'] as String?),
        title: Parse.toStr(map['title']),
        coinCost: Parse.toInt(map['coinCost']),
        subtitle: Parse.toStr(map['subtitle']),
        faceValue: Parse.toDouble(map['faceValue']),
        currency: Parse.toStr(map['currency'], 'RBX'),
        provider: Parse.toStr(map['provider'], 'manual'),
        imageUrl: Parse.toStr(map['imageUrl']),
        badge: Parse.toStr(map['badge']),
        isActive: Parse.toBool(map['isActive'], true),
        sortOrder: Parse.toInt(map['sortOrder']),
        stock: Parse.toInt(map['stock'], -1),
        minVipLevel: Parse.toStr(map['minVipLevel'], 'none'),
        allowedCountries: Parse.toStringList(map['allowedCountries']),
      );

  final String id;
  final RewardKind kind;
  final String title;
  final int coinCost;
  final String subtitle;

  /// The amount printed on the card — Robux for `currency == 'RBX'`, otherwise
  /// a money amount. Display only; the price the user pays is [coinCost].
  final double faceValue;
  final String currency;

  /// Who fulfils it: `manual` (an admin sends the code) or a provider slug
  /// such as `reloadly`.
  final String provider;
  final String imageUrl;

  /// Short marketing label ("Popular", "Best value"), empty for most entries.
  final String badge;
  final bool isActive;
  final int sortOrder;

  /// Remaining units, or `-1` for unlimited. Only `0` blocks redemption, so a
  /// missing field (parsed to `-1`) never accidentally hides a reward.
  final int stock;
  final String minVipLevel;

  /// ISO country codes this reward may be redeemed from. Empty means anywhere
  /// — the common case, so an unset field is permissive by design.
  final List<String> allowedCountries;

  bool get isOutOfStock => stock == 0;

  int get requiredVipRank => AppConstants.vipRank[minVipLevel] ?? 0;

  /// The client-side half of the eligibility check. The server repeats every
  /// one of these in `requestRedemption`; this exists so the UI can explain
  /// *why* a card is locked rather than failing after a round trip.
  ///
  /// Returns null when redeemable.
  RewardLock? lockFor({
    required int balance,
    required int userVipRank,
    required String? countryCode,
  }) {
    if (!isActive) return RewardLock.inactive;
    if (isOutOfStock) return RewardLock.outOfStock;
    if (userVipRank < requiredVipRank) return RewardLock.vipRequired;
    if (allowedCountries.isNotEmpty &&
        (countryCode == null || !allowedCountries.contains(countryCode))) {
      return RewardLock.regionLocked;
    }
    if (balance < coinCost) return RewardLock.insufficientCoins;
    return null;
  }

  /// Bundled artwork path when the catalogue entry has no [imageUrl]. The
  /// directory layout matches the shipped bundle, so ids that had art before
  /// still resolve.
  String get assetFallback => switch (kind) {
        RewardKind.robux => 'assets/images/robux_packages/$id.png',
        _ => 'assets/images/redeem_brand_cards/$id.png',
      };

  @override
  List<Object?> get props => [id, kind, title, coinCost, isActive, stock];
}

/// Why a reward can't be redeemed right now.
enum RewardLock {
  inactive,
  outOfStock,
  vipRequired,
  regionLocked,
  insufficientCoins,
}
