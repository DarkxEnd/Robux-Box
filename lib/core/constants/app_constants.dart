/// Global, non-secret constants shared across the app and mirrored by the
/// Cloud Functions economy (`functions/src/lib/economy.ts`). Any change to the
/// point economy must be made in BOTH places and kept in sync.
abstract final class AppConstants {
  const AppConstants._();

  static const String appName = 'Robux Box';
  static const String defaultCurrencySymbol = 'RBX';

  /// Coins → Robux exchange. The developer margin lives in this ratio: the app
  /// earns more per ad/offer than it pays out, keeping the platform profitable
  /// for the developer while still rewarding the user fairly.
  static const int coinsPerRobux = 100; // 100 coins == 1 Robux payout unit

  /// Referral rewards.
  static const int referrerBonusCoins = 250;
  static const int refereeBonusCoins = 100;
  static const double referralRevenueSharePercent = 0.05; // lifetime 5%

  /// One-time reward for opening the store review flow (see
  /// EarnController.claimRateAppReward) — never tied to the star rating
  /// given, since the store never reports that back to the app.
  static const int rateAppRewardCoins = 250;

  /// Daily streak reward table (index 0 == day 1).
  static const List<int> dailyStreakRewards = [25, 40, 60, 90, 130, 180, 300];

  /// Cumulative XP to reach level N is (N*(N+1)/2) * levelXpStep — a
  /// triangular curve, so early levels come fast (encouraging) and later ones
  /// take progressively longer. See levelForXp() in
  /// functions/src/lib/economy.ts, which this must stay in sync with.
  static const int levelXpStep = 5;

  /// Rewarded-ad economy (base values in coins, before geo-tier multiplier).
  ///
  /// Base payout approximates a ~30% user share of typical rewarded-ad
  /// revenue — there's no exact per-impression revenue figure to split
  /// (unlike [offerwallUserSharePercent], where the provider tells us the
  /// exact payout), so this is a flat estimate rather than a literal
  /// percentage.
  static const int baseRewardedAdCoins = 10;

  /// Rewarded interstitials are a shorter, lower-eCPM format than a full
  /// rewarded video, so they pay proportionally less. Both formats share the
  /// same daily cap and cooldown.
  static const int baseRewardedInterstitialCoins = 3;
  static const int maxRewardedAdsPerDay = 40;
  static const Duration rewardedAdCooldown = Duration(seconds: 30);

  /// Offerwall economy — reward is provider-driven; this is the minimum the app
  /// will credit and the app's cut is enforced server-side.
  static const double offerwallUserSharePercent = 0.30;

  /// VIP tiers unlock multipliers and lower withdrawal minimums.
  static const Map<String, double> vipMultipliers = {
    'none': 1.0,
    'bronze': 1.25,
    'silver': 1.50,
    'gold': 2.0,
    'diamond': 3.0,
  };

  /// Raised daily rewarded-ad cap per VIP tier (replaces the flat
  /// [maxRewardedAdsPerDay] once a tier is active).
  static const Map<String, int> vipMaxAdsPerDay = {
    'none': 40,
    'bronze': 55,
    'silver': 70,
    'gold': 90,
    'diamond': 120,
  };

  /// Numeric rank of each VIP tier, matching [Reward.minVipLevel] gating and
  /// the server's `vipRank()`.
  static const Map<String, int> vipRank = {
    'none': 0,
    'bronze': 1,
    'silver': 2,
    'gold': 3,
    'diamond': 4,
  };

  /// A purchased VIP subscription lasts this many days before it lapses back
  /// to `none` (see the server's `vipExpiryDowngrade` scheduled job). Admin-
  /// granted VIP (via the dashboard) has no expiry and stays permanent.
  static const int vipDurationDays = 30;

  /// Coin price for a [vipDurationDays]-day subscription. Gold and Diamond are
  /// intentionally absent — they're real-money-only (see [vipMoneyPrices]).
  static const Map<String, int> vipCoinPrices = {
    'bronze': 12000,
    'silver': 30000,
  };

  /// Flat coin bonus a VIP member can claim once per UTC day, on top of the
  /// earn-rate multiplier — see the server's `claimVipDailyBonus`. `none`
  /// isn't listed, so a lapsed subscription simply has no entry to claim.
  ///
  /// Sized so a member who claims every single day over one
  /// [vipDurationDays] (30-day) window gets back their subscription price +
  /// 40% in coins: dailyBonus * 30 == price * 1.4.
  static const Map<String, int> vipDailyBonusCoins = {
    'bronze': 560,
    'silver': 1400,
    'gold': 3730,
    'diamond': 7460,
  };

  /// Real-money price shown before the store connects (e.g. web preview /
  /// no billing on this platform); the actual charged price always comes from
  /// the store via [vipIapProductIds] once `in_app_purchase` loads the product.
  static const Map<String, String> vipMoneyPrices = {
    'bronze': '\$1.99',
    'silver': '\$4.99',
    'gold': '\$9.99',
    'diamond': '\$19.99',
  };

  /// Play Store / App Store product ids for the real-money VIP subscriptions.
  /// These must be created in the Play Console / App Store Connect with
  /// matching ids — see docs/DEPLOYMENT.md.
  static const Map<String, String> vipIapProductIds = {
    'bronze': 'vip_bronze_30d',
    'silver': 'vip_silver_30d',
    'gold': 'vip_gold_30d',
    'diamond': 'vip_diamond_30d',
  };

  /// Anti-fraud thresholds (client-side pre-checks; authoritative checks run in
  /// Cloud Functions).
  static const int maxDevicesPerAccount = 3;
  static const int suspiciousVelocityCoinsPerMinute = 500;

  static const int leaderboardPageSize = 50;
  static const int transactionsPageSize = 25;

  /// Spin-wheel segment prizes (coins). Order MUST match the server
  /// (`functions/src/lib/economy.ts` → spinPrizes) so the wheel lands on the
  /// exact segment the backend awarded.
  static const List<int> spinWheelPrizes = [25, 50, 10, 100, 250, 15, 500, 75];

  /// Lucky-chest prizes (coins), mirroring the server chestPrizes.
  static const List<int> chestPrizes = [30, 60, 120, 300];
}

/// The four monetisation tiers derived from the user's country. T1 pays the
/// most (high eCPM markets), T4 the least. The multiplier scales every earning.
enum GeoTier {
  t1(1, 1.00, 'T1'),
  t2(2, 0.70, 'T2'),
  t3(3, 0.45, 'T3'),
  t4(4, 0.28, 'T4');

  const GeoTier(this.level, this.multiplier, this.label);

  final int level;
  final double multiplier;
  final String label;

  static GeoTier fromLevel(int level) =>
      GeoTier.values.firstWhere((t) => t.level == level,
          orElse: () => GeoTier.t4);
}
