import 'package:equatable/equatable.dart';

import '../core/constants/app_constants.dart';
import 'model_utils.dart';

/// The user profile document (`users/{uid}`). The coin balance lives in
/// `wallets/{uid}`, not here — see [Wallet].
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
    this.robloxUsername,
    this.countryCode,
    this.status = 'active',
    this.vipLevel = 'none',
    this.vipExpiresAt,
    this.xp = 0,
    this.level = 0,
    this.dailyStreak = 0,
    this.adsWatchedToday = 0,
    this.lastAdAt,
    this.lastDailyRewardAt,
    this.lastVipBonusAt,
    this.lastSpinAt,
    this.lastChestAt,
    this.referralCode,
    this.referredBy,
    this.isAdmin = false,
    this.rateAppRewardClaimed = false,
    this.createdAt,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
        uid: uid,
        email: map['email'] as String?,
        displayName: map['displayName'] as String?,
        photoUrl: map['photoUrl'] as String?,
        phoneNumber: map['phoneNumber'] as String?,
        robloxUsername: map['robloxUsername'] as String?,
        countryCode: map['countryCode'] as String?,
        status: Parse.toStr(map['status'], 'active'),
        vipLevel: Parse.toStr(map['vipLevel'], 'none'),
        vipExpiresAt: Parse.toDate(map['vipExpiresAt']),
        xp: Parse.toInt(map['xp']),
        level: Parse.toInt(map['level']),
        dailyStreak: Parse.toInt(map['dailyStreak']),
        adsWatchedToday: Parse.toInt(map['adsWatchedToday']),
        lastAdAt: Parse.toDate(map['lastAdAt']),
        lastDailyRewardAt: Parse.toDate(map['lastDailyRewardAt']),
        lastVipBonusAt: Parse.toDate(map['lastVipBonusAt']),
        lastSpinAt: Parse.toDate(map['lastSpinAt']),
        lastChestAt: Parse.toDate(map['lastChestAt']),
        referralCode: map['referralCode'] as String?,
        referredBy: map['referredBy'] as String?,
        isAdmin: Parse.toBool(map['isAdmin']),
        rateAppRewardClaimed: Parse.toBool(map['rateAppRewardClaimed']),
        createdAt: Parse.toDate(map['createdAt']),
      );

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? phoneNumber;
  final String? robloxUsername;
  final String? countryCode;
  final String status;
  final String vipLevel;
  final DateTime? vipExpiresAt;
  final int xp;
  final int level;
  final int dailyStreak;
  final int adsWatchedToday;
  final DateTime? lastAdAt;
  final DateTime? lastDailyRewardAt;
  final DateTime? lastVipBonusAt;
  final DateTime? lastSpinAt;
  final DateTime? lastChestAt;
  final String? referralCode;
  final String? referredBy;
  final bool isAdmin;
  final bool rateAppRewardClaimed;
  final DateTime? createdAt;

  /// VIP as it should be treated *right now*. The stored level can be stale
  /// for up to a day (the downgrade job runs nightly), so every benefit check
  /// must go through this rather than [vipLevel].
  String get effectiveVipLevel {
    if (vipLevel == 'none') return 'none';
    final exp = vipExpiresAt;
    if (exp != null && exp.isBefore(DateTime.now())) return 'none';
    return vipLevel;
  }

  bool get isVip => effectiveVipLevel != 'none';

  int get vipRank => AppConstants.vipRank[effectiveVipLevel] ?? 0;

  double get earnMultiplier =>
      AppConstants.vipMultipliers[effectiveVipLevel] ?? 1.0;

  /// The daily rewarded-ad cap for this user's tier. Using the flat constant
  /// instead of this is a bug that has shipped before: it capped Diamond
  /// members at 40 ads while the server allowed 120.
  int get maxAdsPerDay =>
      AppConstants.vipMaxAdsPerDay[effectiveVipLevel] ??
      AppConstants.maxRewardedAdsPerDay;

  /// Ads watched today, ignoring a counter left over from a previous day.
  int get adsWatchedTodayEffective {
    final last = lastAdAt;
    if (last == null) return 0;
    final now = DateTime.now().toUtc();
    final l = last.toUtc();
    final sameDay =
        l.year == now.year && l.month == now.month && l.day == now.day;
    return sameDay ? adsWatchedToday : 0;
  }

  int get adsLeftToday =>
      (maxAdsPerDay - adsWatchedTodayEffective).clamp(0, maxAdsPerDay);

  bool get isBanned => status == 'banned';
  bool get isRestricted => status == 'restricted';

  bool get canClaimDailyReward => !_isSameUtcDayAsNow(lastDailyRewardAt);
  bool get canClaimVipBonus => isVip && !_isSameUtcDayAsNow(lastVipBonusAt);
  bool get canSpin => !_isSameUtcDayAsNow(lastSpinAt);
  bool get canOpenChest => !_isSameUtcDayAsNow(lastChestAt);

  static bool _isSameUtcDayAsNow(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now().toUtc();
    final v = d.toUtc();
    return v.year == now.year && v.month == now.month && v.day == now.day;
  }

  @override
  List<Object?> get props => [
        uid, vipLevel, vipExpiresAt, xp, level, dailyStreak,
        adsWatchedToday, lastAdAt, status, displayName, photoUrl,
      ];
}
