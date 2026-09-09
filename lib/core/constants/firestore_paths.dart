/// Every Firestore path the app touches, in one place.
///
/// These strings are verified against the shipped bundle — the published app
/// already writes documents at exactly these paths. Renaming one here does not
/// migrate anything; it orphans the existing data. The server mirrors this list
/// in `functions/src/lib/admin.ts` and the two must stay in sync.
abstract final class FsPaths {
  const FsPaths._();

  // Top-level collections.
  static const users = 'users';
  static const wallets = 'wallets';
  static const transactions = 'transactions';
  static const rewards = 'rewards';
  static const redemptions = 'redemptions';
  static const achievements = 'achievements';
  static const leaderboards = 'leaderboards';
  static const promocodes = 'promocodes';
  static const banners = 'banners';
  static const config = 'config';
  static const geoTiers = 'geo_tiers';
  static const offers = 'offers';
  static const reports = 'reports';
  static const vipPurchases = 'vip_purchases';

  /// camelCase, unlike every other multi-word collection above. That is what
  /// the shipped client reads, so it is not a typo to be tidied up.
  static const supportTickets = 'supportTickets';
  static const ticketCategories = 'ticketCategories';

  // Sub-collections under users/{uid}.
  static const userAchievements = 'achievements';
  static const userNotifications = 'notifications';
  static const userDevices = 'devices';

  // Fixed config documents.
  static const configEconomy = 'economy';
  static const configFeatureFlags = 'feature_flags';
  static const configMaintenance = 'maintenance';
  static const geoTierOverrides = 'overrides';

  /// Entries under `leaderboards/{period}`.
  static const leaderboardEntries = 'entries';
}
