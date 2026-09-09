import 'package:flutter_test/flutter_test.dart';
import 'package:robux_box/core/constants/app_constants.dart';
import 'package:robux_box/models/app_user.dart';
import 'package:robux_box/models/model_utils.dart';
import 'package:robux_box/models/redemption.dart';
import 'package:robux_box/models/reward.dart';
import 'package:robux_box/models/transaction.dart';
import 'package:robux_box/models/wallet.dart';

void main() {
  group('Parse', () {
    test('coerces the shapes Firestore actually returns', () {
      expect(Parse.toInt(5), 5);
      expect(Parse.toInt(5.7), 6);
      expect(Parse.toInt('12'), 12);
      expect(Parse.toInt('nonsense'), 0);
      expect(Parse.toInt(null, 9), 9);

      expect(Parse.toDouble(1), 1.0);
      expect(Parse.toDouble('2.5'), 2.5);

      expect(Parse.toBool(true), isTrue);
      expect(Parse.toBool(1), isTrue);
      expect(Parse.toBool(0), isFalse);
      expect(Parse.toBool('true'), isTrue);
      expect(Parse.toBool(null, true), isTrue);

      expect(Parse.toStringList(['a', 1]), ['a', '1']);
      expect(Parse.toStringList('not a list'), isEmpty);
    });

    test('never throws on a malformed document', () {
      // One bad document must not take a whole list screen down.
      expect(() => Parse.toInt(Object()), returnsNormally);
      expect(() => Parse.toDate('not a date'), returnsNormally);
      expect(Parse.toDate('not a date'), isNull);
      expect(Parse.toMap('not a map'), isEmpty);
    });
  });

  group('Wallet', () {
    test('reads the coins field, not balance', () {
      // The server writes `coins`. Reading `balance` shows every user zero,
      // which is the bug this test exists to catch.
      final wallet = Wallet.fromMap('u1', {
        'coins': 1234,
        'lifetimeEarned': 5000,
        'lifetimeSpent': 3766,
      });

      expect(wallet.balance, 1234);
      expect(wallet.lifetimeEarned, 5000);
      expect(wallet.lifetimeSpent, 3766);
    });

    test('a missing wallet reads as zero rather than throwing', () {
      expect(Wallet.fromMap('u1', {}).balance, 0);
      expect(const Wallet.empty('u1').balance, 0);
    });

    test('canAfford is inclusive at the exact price', () {
      const wallet = Wallet(uid: 'u1', balance: 100);
      expect(wallet.canAfford(100), isTrue);
      expect(wallet.canAfford(101), isFalse);
    });
  });

  group('AppUser VIP', () {
    test('an expired subscription is treated as none immediately', () {
      // The downgrade job runs nightly, so the stored level can be a day
      // stale; every benefit check has to go through effectiveVipLevel.
      final expired = AppUser(
        uid: 'u1',
        vipLevel: 'gold',
        vipExpiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(expired.effectiveVipLevel, 'none');
      expect(expired.isVip, isFalse);
      expect(expired.earnMultiplier, 1.0);
    });

    test('an unexpired subscription keeps its benefits', () {
      final active = AppUser(
        uid: 'u1',
        vipLevel: 'gold',
        vipExpiresAt: DateTime.now().add(const Duration(days: 5)),
      );
      expect(active.effectiveVipLevel, 'gold');
      expect(active.earnMultiplier, 2.0);
      expect(active.maxAdsPerDay, 90);
    });

    test('admin-granted VIP with no expiry never lapses', () {
      const granted = AppUser(uid: 'u1', vipLevel: 'diamond');
      expect(granted.effectiveVipLevel, 'diamond');
      expect(granted.maxAdsPerDay, 120);
    });

    test('the ad cap follows the tier, not the flat constant', () {
      // Using maxRewardedAdsPerDay directly capped Diamond members at 40
      // while the server allowed 120. That bug has shipped before.
      const diamond = AppUser(uid: 'u1', vipLevel: 'diamond');
      expect(diamond.maxAdsPerDay, isNot(AppConstants.maxRewardedAdsPerDay));
      expect(diamond.maxAdsPerDay, 120);
    });
  });

  group('AppUser daily counters', () {
    test('yesterday\'s ad count does not carry into today', () {
      final stale = AppUser(
        uid: 'u1',
        adsWatchedToday: 40,
        lastAdAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
      );
      expect(stale.adsWatchedTodayEffective, 0);
      expect(stale.adsLeftToday, 40);
    });

    test('today\'s ad count is honoured', () {
      final today = AppUser(
        uid: 'u1',
        adsWatchedToday: 12,
        lastAdAt: DateTime.now().toUtc(),
      );
      expect(today.adsWatchedTodayEffective, 12);
      expect(today.adsLeftToday, 28);
    });

    test('adsLeftToday never goes negative', () {
      final over = AppUser(
        uid: 'u1',
        adsWatchedToday: 99,
        lastAdAt: DateTime.now().toUtc(),
      );
      expect(over.adsLeftToday, 0);
    });

    test('a claim made today blocks a second claim', () {
      final claimed = AppUser(
        uid: 'u1',
        lastDailyRewardAt: DateTime.now().toUtc(),
      );
      expect(claimed.canClaimDailyReward, isFalse);

      const never = AppUser(uid: 'u1');
      expect(never.canClaimDailyReward, isTrue);
    });
  });

  group('Reward.lockFor', () {
    const reward = Reward(
      id: 'robux_400',
      kind: RewardKind.robux,
      title: '400 Robux',
      coinCost: 38000,
    );

    test('unlocked when everything checks out', () {
      expect(
        reward.lockFor(balance: 40000, userVipRank: 0, countryCode: 'US'),
        isNull,
      );
    });

    test('reports the specific reason, not a generic failure', () {
      expect(
        reward.lockFor(balance: 100, userVipRank: 0, countryCode: 'US'),
        RewardLock.insufficientCoins,
      );

      const vipOnly = Reward(
        id: 'x',
        kind: RewardKind.giftCard,
        title: 'x',
        coinCost: 10,
        minVipLevel: 'gold',
      );
      expect(
        vipOnly.lockFor(balance: 999999, userVipRank: 1, countryCode: 'US'),
        RewardLock.vipRequired,
      );

      const regional = Reward(
        id: 'x',
        kind: RewardKind.giftCard,
        title: 'x',
        coinCost: 10,
        allowedCountries: ['GB'],
      );
      expect(
        regional.lockFor(balance: 999999, userVipRank: 0, countryCode: 'US'),
        RewardLock.regionLocked,
      );
    });

    test('an empty country list means available everywhere', () {
      expect(
        reward.lockFor(balance: 40000, userVipRank: 0, countryCode: null),
        isNull,
      );
    });

    test('stock of -1 is unlimited; only 0 blocks', () {
      expect(reward.isOutOfStock, isFalse);
      const none = Reward(
        id: 'x',
        kind: RewardKind.giftCard,
        title: 'x',
        coinCost: 10,
        stock: 0,
      );
      expect(
        none.lockFor(balance: 999, userVipRank: 0, countryCode: null),
        RewardLock.outOfStock,
      );
    });
  });

  group('Redemption status', () {
    test('only pending is user-cancellable', () {
      // Once an admin starts processing, a code may already have been bought.
      expect(RedemptionStatus.pending.isCancellableByUser, isTrue);
      expect(RedemptionStatus.processing.isCancellableByUser, isFalse);
      expect(RedemptionStatus.completed.isCancellableByUser, isFalse);
    });

    test('rejected and cancelled refund; completed does not', () {
      expect(RedemptionStatus.rejected.wasRefunded, isTrue);
      expect(RedemptionStatus.cancelled.wasRefunded, isTrue);
      expect(RedemptionStatus.completed.wasRefunded, isFalse);
    });

    test('unknown wire values fall back to pending', () {
      expect(RedemptionStatus.fromWire('who_knows'), RedemptionStatus.pending);
      expect(RedemptionStatus.fromWire(null), RedemptionStatus.pending);
    });
  });

  group('AppTransaction', () {
    test('an unknown server type does not throw', () {
      // A new type can ship server-side before the app knows it.
      final tx = AppTransaction.fromMap('t1', {
        'uid': 'u1',
        'type': 'something_new',
        'coins': 10,
      });
      expect(tx.type, TxType.other);
    });

    test('sign carries the direction', () {
      final credit = AppTransaction.fromMap('t1', {'uid': 'u', 'coins': 50});
      final debit = AppTransaction.fromMap('t2', {'uid': 'u', 'coins': -50});
      expect(credit.isCredit, isTrue);
      expect(debit.isDebit, isTrue);
    });

    test('every wire value is unique', () {
      final wires = TxType.values.map((t) => t.wire).toList();
      expect(wires.toSet().length, wires.length);
    });
  });
}
