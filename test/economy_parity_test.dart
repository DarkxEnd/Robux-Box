import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robux_box/core/constants/app_constants.dart';
import 'package:robux_box/core/services/tier_map.dart';

/// Guards the one thing that silently costs real money: the client economy
/// drifting from the server's.
///
/// `lib/core/constants/app_constants.dart` and
/// `functions/src/lib/economy.ts` hold the same numbers in two languages. If
/// they disagree, the app promises one payout and the server delivers another
/// — and the user is the one who notices. Rather than trusting a comment that
/// says "keep these in sync", this reads the TypeScript and checks.
void main() {
  late final String economyTs;

  setUpAll(() {
    final file = File('functions/src/lib/economy.ts');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'economy.ts must exist for this parity check to mean anything',
    );
    economyTs = file.readAsStringSync();
  });

  /// Pulls `name: <number>` out of the TypeScript source.
  num? tsNumber(String source, String name) {
    final match = RegExp('$name:\\s*([0-9]+(?:\\.[0-9]+)?)').firstMatch(source);
    return match == null ? null : num.parse(match.group(1)!);
  }

  /// Pulls one entry out of a TS object literal, e.g. bronze: 1.25.
  num? tsMapEntry(String source, String map, String key) {
    final block = RegExp(
      '$map\\s*:\\s*\\{([^}]*)\\}',
      dotAll: true,
    ).firstMatch(source)?.group(1);
    if (block == null) return null;
    return tsNumber(block, key);
  }

  group('client and server economy agree', () {
    test('coinsPerRobux', () {
      expect(tsNumber(economyTs, 'coinsPerRobux'), AppConstants.coinsPerRobux);
    });

    test('base rewarded-ad payouts', () {
      expect(
        tsNumber(economyTs, 'baseRewardedAdCoins'),
        AppConstants.baseRewardedAdCoins,
      );
      expect(
        tsNumber(economyTs, 'baseRewardedInterstitialCoins'),
        AppConstants.baseRewardedInterstitialCoins,
      );
    });

    test('offerwall user share', () {
      // The number that decides how a provider payout is split. A mismatch
      // here means the app advertises one rate and pays another.
      expect(
        tsNumber(economyTs, 'offerwallUserSharePercent'),
        AppConstants.offerwallUserSharePercent,
      );
    });

    test('VIP multipliers', () {
      for (final entry in AppConstants.vipMultipliers.entries) {
        if (entry.key == 'none') continue;
        expect(
          tsMapEntry(economyTs, 'vipMultipliers', entry.key),
          entry.value,
          reason: 'vipMultipliers.${entry.key} differs from the server',
        );
      }
    });

    test('VIP daily ad caps', () {
      for (final entry in AppConstants.vipMaxAdsPerDay.entries) {
        expect(
          tsMapEntry(economyTs, 'vipMaxAdsPerDay', entry.key),
          entry.value,
          reason: 'vipMaxAdsPerDay.${entry.key} differs from the server',
        );
      }
    });

    test('VIP coin prices', () {
      for (final entry in AppConstants.vipCoinPrices.entries) {
        expect(
          tsMapEntry(economyTs, 'vipCoinPrices', entry.key),
          entry.value,
          reason: 'vipCoinPrices.${entry.key} differs from the server',
        );
      }
    });

    test('VIP daily bonus coins', () {
      for (final entry in AppConstants.vipDailyBonusCoins.entries) {
        expect(
          tsMapEntry(economyTs, 'vipDailyBonusCoins', entry.key),
          entry.value,
          reason: 'vipDailyBonusCoins.${entry.key} differs from the server',
        );
      }
    });
  });

  group('economy invariants', () {
    test('a VIP subscription pays for itself in daily bonuses', () {
      // Sized so a member who claims every day over one 30-day window gets
      // back their price plus 40%. If this breaks, a tier is either
      // worthless or free money.
      for (final tier in AppConstants.vipCoinPrices.keys) {
        final price = AppConstants.vipCoinPrices[tier]!;
        final daily = AppConstants.vipDailyBonusCoins[tier]!;
        final returned = daily * AppConstants.vipDurationDays;
        expect(
          returned / price,
          closeTo(1.4, 0.02),
          reason: '$tier does not return price + 40% over a full month',
        );
      }
    });

    test('VIP ranks are strictly ordered', () {
      const order = ['none', 'bronze', 'silver', 'gold', 'diamond'];
      for (var i = 1; i < order.length; i++) {
        expect(
          AppConstants.vipRank[order[i]]!,
          greaterThan(AppConstants.vipRank[order[i - 1]]!),
        );
        expect(
          AppConstants.vipMultipliers[order[i]]!,
          greaterThan(AppConstants.vipMultipliers[order[i - 1]]!),
        );
        expect(
          AppConstants.vipMaxAdsPerDay[order[i]]!,
          greaterThan(AppConstants.vipMaxAdsPerDay[order[i - 1]]!),
        );
      }
    });

    test('the daily streak ladder only ever goes up', () {
      const rewards = AppConstants.dailyStreakRewards;
      for (var i = 1; i < rewards.length; i++) {
        expect(rewards[i], greaterThan(rewards[i - 1]));
      }
    });

    test('an interstitial pays less than a full rewarded video', () {
      expect(
        AppConstants.baseRewardedInterstitialCoins,
        lessThan(AppConstants.baseRewardedAdCoins),
      );
    });

    test('the spin wheel has segments and the client knows all of them', () {
      expect(AppConstants.spinWheelPrizes, isNotEmpty);
      expect(AppConstants.chestPrizes, isNotEmpty);
      // The server returns a segment index; an off-by-one list here would
      // land the wheel on a different prize than the one credited.
      expect(AppConstants.spinWheelPrizes.every((p) => p > 0), isTrue);
    });
  });

  group('TierMap', () {
    test('unknown and malformed countries fall to the lowest tier', () {
      // Guessing high would overpay in a market where ad revenue does not
      // cover it.
      expect(TierMap.tierFor(null), 4);
      expect(TierMap.tierFor(''), 4);
      expect(TierMap.tierFor('XX'), 4);
      expect(TierMap.tierFor('USA'), 4);
    });

    test('known markets map to their tier, case-insensitively', () {
      expect(TierMap.tierFor('US'), 1);
      expect(TierMap.tierFor('us'), 1);
      expect(TierMap.tierFor('FR'), 2);
      expect(TierMap.tierFor('BR'), 3);
      expect(TierMap.tierFor('EG'), 4);
    });

    test('multipliers decrease as the tier number rises', () {
      for (var t = 2; t <= 4; t++) {
        expect(
          TierMap.multiplierFor(t),
          lessThan(TierMap.multiplierFor(t - 1)),
        );
      }
      expect(TierMap.multiplierFor(1), 1.0);
    });

    test('client tier multipliers match the server', () {
      final block = RegExp(
        r'TIER_MULTIPLIERS[^{]*\{([^}]*)\}',
        dotAll: true,
      ).firstMatch(economyTs)?.group(1);
      expect(
        block,
        isNotNull,
        reason: 'TIER_MULTIPLIERS not found in economy.ts',
      );

      for (final entry in TierMap.multipliers.entries) {
        final match = RegExp('${entry.key}:\\s*([0-9.]+)').firstMatch(block!);
        expect(match, isNotNull, reason: 'tier ${entry.key} missing on server');
        expect(
          num.parse(match!.group(1)!),
          entry.value,
          reason: 'tier ${entry.key} multiplier differs from the server',
        );
      }
    });
  });
}
