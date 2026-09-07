import * as adminSdk from "firebase-admin";

if (adminSdk.apps.length === 0) {
  adminSdk.initializeApp();
}

export const admin = adminSdk;
export const db = adminSdk.firestore();
export const auth = adminSdk.auth();
export const messaging = adminSdk.messaging();
export const storage = adminSdk.storage();

export const Timestamp = adminSdk.firestore.Timestamp;
export const FieldValue = adminSdk.firestore.FieldValue;

/** The user profile document. Balances live in `wallets/{uid}`, not here. */
export function userDoc(uid: string) {
  return db.collection("users").doc(uid);
}

/** The wallet document — coin balance and lifetime stats. Client-read-only. */
export function walletDoc(uid: string) {
  return db.collection("wallets").doc(uid);
}

/**
 * Every root collection the backend touches, in one place so a typo becomes a
 * compile error instead of a silently-empty query.
 */
export const cols = {
  users: db.collection("users"),
  wallets: db.collection("wallets"),
  rewards: db.collection("rewards"),
  redemptions: db.collection("redemptions"),
  offers: db.collection("offers"),
  offerCompletions: db.collection("offer_completions"),
  adImpressions: db.collection("ad_impressions"),
  nonces: db.collection("nonces"),
  rateLimits: db.collection("rate_limits"),
  fraudFlags: db.collection("fraud_flags"),
  promocodes: db.collection("promocodes"),
  banners: db.collection("banners"),
  leaderboards: db.collection("leaderboards"),
  achievements: db.collection("achievements"),
  notifications: db.collection("notifications"),
  vipPurchases: db.collection("vip_purchases"),
  // camelCase, unlike the other multi-word collections — matches what the
  // shipped client actually reads, so don't "fix" it to snake_case.
  supportTickets: db.collection("supportTickets"),
  ticketCategories: db.collection("ticketCategories"),
  auditLogs: db.collection("audit_logs"),
  analytics: db.collection("analytics"),
  config: db.collection("config"),
  geoTiers: db.collection("geo_tiers"),
} as const;

/** Per-user subcollections. */
export const subcols = {
  transactions: (uid: string) => userDoc(uid).collection("transactions"),
  devices: (uid: string) => userDoc(uid).collection("devices"),
  achievements: (uid: string) => userDoc(uid).collection("achievements"),
  notifications: (uid: string) => userDoc(uid).collection("notifications"),
};
