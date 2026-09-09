/**
 * Robux Box — Cloud Functions entry point.
 *
 * All business logic that touches the economy runs here with the Admin SDK,
 * which bypasses Firestore security rules. This is the trust boundary: clients
 * can only *request* actions; the server validates and applies them.
 *
 * Grouped exports:
 *   • earn        — rewarded ads, daily reward, promo codes, tier resolution
 *   • games       — spin wheel / lucky chest
 *   • vip         — coin + real-money subscription purchase, daily bonus
 *   • redemption  — request/cancel + admin processing
 *   • offerwall   — signed URL (callable) + provider postbacks / AdMob SSV
 *   • admin       — claims, coin adjustments, status, VIP, promocodes, broadcast
 *   • triggers    — account provisioning/cleanup, referrals, achievements
 *   • scheduled   — daily reset, leaderboards, VIP expiry, reminder campaigns
 */

// Callable: earning
export {
  beginRewardedAd,
  confirmRewardedAd,
  claimDailyReward,
  redeemPromocode,
  resolveTier,
  claimRateAppReward,
  recentTransactions,
} from "./handlers/earn";

// Callable: daily games (spin wheel / lucky chest)
export {playDailyGame} from "./handlers/games";

// Callable: VIP subscription purchase + daily bonus
export {
  purchaseVipWithCoins,
  verifyVipPurchase,
  claimVipDailyBonus,
} from "./handlers/vip";

// Callable: redemption
export {
  requestRedemption,
  cancelRedemption,
  processRedemption,
  deleteRedemption,
} from "./handlers/redemption";

// Callable + HTTP: offerwall & ads verification
export {
  getOfferwallUrl,
  offerwallPostback,
  cpaleadPostback,
  lootwallsPostback,
  admobSsv,
} from "./handlers/offerwall";

// Callable: admin dashboard
export {
  setAdminClaim,
  refreshAnalytics,
  adjustCoins,
  setAccountStatus,
  setVipLevel,
  setUserLevel,
  upsertPromocode,
  broadcastNotification,
  listUsers,
} from "./handlers/admin";

// Auth / Firestore triggers
export {
  onUserCreated,
  applyReferralOnProfile,
  onUserDeleted,
} from "./triggers/auth";

// Firestore trigger: achievement progress + coin payout
export {syncAchievementsOnWalletWrite} from "./triggers/achievements";

// Scheduled
export {
  resetDailyCounters,
  aggregateLeaderboards,
  analyticsAggregate,
  vipExpiryDowngrade,
  dailyReminder,
  rewardReminder,
  vipReminder,
  referralReminder,
} from "./triggers/scheduled";
