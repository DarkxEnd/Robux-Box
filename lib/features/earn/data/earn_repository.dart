import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/error/result.dart';
import '../../../core/services/callable_service.dart';

/// Result of `beginRewardedAd` — the nonce that binds an ad impression to this
/// user and this request.
class AdSession {
  const AdSession({
    required this.nonce,
    required this.adsLeft,
    required this.format,
  });

  factory AdSession.fromMap(Map<String, dynamic> map) => AdSession(
    nonce: (map['nonce'] as String?) ?? '',
    adsLeft: (map['adsLeft'] as num?)?.toInt() ?? 0,
    format: (map['format'] as String?) ?? 'rewarded',
  );

  final String nonce;
  final int adsLeft;
  final String format;
}

/// Result of any coin-granting call.
class EarnResult {
  const EarnResult({required this.coins, this.balance, this.extra = const {}});

  factory EarnResult.fromMap(Map<String, dynamic> map) => EarnResult(
    coins: (map['coins'] as num?)?.toInt() ?? 0,
    balance: (map['balance'] as num?)?.toInt(),
    extra: map,
  );

  /// Coins granted by this action. Always comes from the server — the client
  /// never computes a payout, because a client that could would be the whole
  /// attack surface.
  final int coins;
  final int? balance;
  final Map<String, dynamic> extra;

  int? get streak => (extra['streak'] as num?)?.toInt();
  int? get adsLeft => (extra['adsLeft'] as num?)?.toInt();

  /// Which wheel segment the server picked, so the animation can land on it.
  int? get index => (extra['index'] as num?)?.toInt();
}

/// Every way to earn coins, all of them server-decided.
class EarnRepository {
  const EarnRepository(this._callables);

  final CallableService _callables;

  /// Step 1 of the ad flow. [device] is the fingerprint from
  /// SecureStorageService; the server treats it as a signal, not proof.
  Future<Result<AdSession>> beginRewardedAd({
    required String format,
    required Map<String, dynamic> device,
  }) async {
    final res = await _callables.call('beginRewardedAd', {
      'format': format,
      'device': device,
    });
    return res.map(AdSession.fromMap);
  }

  /// Step 2. Consumes the nonce and credits coins.
  ///
  /// In strict SSV mode this fails unless AdMob's signed callback has already
  /// written a verified impression for the nonce — so calling it without
  /// actually watching an ad earns nothing.
  Future<Result<EarnResult>> confirmRewardedAd(String nonce) async {
    final res = await _callables.call('confirmRewardedAd', {'nonce': nonce});
    return res.map(EarnResult.fromMap);
  }

  Future<Result<EarnResult>> claimDailyReward() async {
    final res = await _callables.call('claimDailyReward');
    return res.map(EarnResult.fromMap);
  }

  /// `spin` or `chest`.
  Future<Result<EarnResult>> playDailyGame(String game) async {
    final res = await _callables.call('playDailyGame', {'game': game});
    return res.map(EarnResult.fromMap);
  }

  Future<Result<EarnResult>> redeemPromocode(String code) async {
    final res = await _callables.call('redeemPromocode', {
      'code': code.trim().toUpperCase(),
    });
    return res.map(EarnResult.fromMap);
  }

  /// One-time reward for opening the store review flow.
  ///
  /// Never tied to the rating given — the in-app review API does not report it
  /// back, and paying for positive ratings breaches Play Store policy.
  Future<Result<EarnResult>> claimRateAppReward() async {
    final res = await _callables.call('claimRateAppReward');
    return res.map(EarnResult.fromMap);
  }

  Future<Result<EarnResult>> claimVipDailyBonus() async {
    final res = await _callables.call('claimVipDailyBonus');
    return res.map(EarnResult.fromMap);
  }

  /// Resolves the geo tier, optionally hinting a country. The hint is only
  /// used the first time; afterwards the country of record wins.
  Future<Result<Map<String, dynamic>>> resolveTier({String? countryCode}) =>
      _callables.call('resolveTier', {
        if (countryCode != null) 'countryCode': countryCode,
      });
}

final earnRepositoryProvider = Provider<EarnRepository>((ref) {
  return EarnRepository(ref.watch(callableServiceProvider));
});

/// The user's geo tier and today's ad allowance, refreshed on demand.
final tierProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  // Rebuild on sign-in/out so a second account does not inherit the first
  // account's tier.
  ref.watch(currentUidProvider);
  final country = await ref.read(geoTierServiceProvider).detectCountryCode();
  final res = await ref
      .read(earnRepositoryProvider)
      .resolveTier(countryCode: country);
  return res.valueOrNull ?? const {};
});
