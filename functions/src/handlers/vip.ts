import {onCall, HttpsError} from "firebase-functions/v2/https";
import {cols, userDoc, Timestamp} from "../lib/admin";
import {ECONOMY, effectiveVipLevel, isSameUtcDay} from "../lib/economy";
import {creditWallet, debitWallet} from "../lib/wallet";
import {verifyPlaySubscription} from "../lib/playPublisher";
import {
  CALLABLE_OPTS,
  assertAccountActive,
  auditLog,
  rateLimit,
  requireAuth,
} from "../lib/security";
import {sendUserNotification} from "../lib/notify";

const TIERS = ["bronze", "silver", "gold", "diamond"] as const;
type Tier = typeof TIERS[number];

/** Product id → tier, matching AppConstants.vipIapProductIds exactly. */
const PRODUCT_TIERS: Record<string, Tier> = {
  vip_bronze_30d: "bronze",
  vip_silver_30d: "silver",
  vip_gold_30d: "gold",
  vip_diamond_30d: "diamond",
};

function expiryFromNow(existing?: FirebaseFirestore.Timestamp | null): FirebaseFirestore.Timestamp {
  // Extend from the current expiry when still active, so re-subscribing early
  // adds time instead of throwing away what's left.
  const base = existing && existing.toMillis() > Date.now() ?
    existing.toMillis() :
    Date.now();
  return Timestamp.fromMillis(base + ECONOMY.vipDurationDays * 24 * 60 * 60 * 1000);
}

/**
 * Buys Bronze/Silver with coins. Gold and Diamond are deliberately absent from
 * `vipCoinPrices` — they are real-money-only, and that is enforced here rather
 * than only in the UI.
 */
export const purchaseVipWithCoins = onCall(CALLABLE_OPTS, async (req) => {
  const uid = requireAuth(req);
  await assertAccountActive(uid);
  await rateLimit(uid, "vip_purchase", 10, 3600);

  const tier = String(req.data?.tier ?? "") as Tier;
  const price = ECONOMY.vipCoinPrices[tier];
  if (!price) {
    throw new HttpsError(
      "invalid-argument",
      "That tier can only be purchased with real money.",
    );
  }

  const snap = await userDoc(uid).get();
  const current = snap.data() ?? {};

  await debitWallet({
    uid,
    amount: price,
    type: "vip_purchase",
    title: `VIP ${tier} — ${ECONOMY.vipDurationDays} days`,
    metadata: {tier, method: "coins"},
  });

  const expiresAt = expiryFromNow(
    current.vipExpiresAt as FirebaseFirestore.Timestamp | null,
  );
  await userDoc(uid).set(
    {vipLevel: tier, vipExpiresAt: expiresAt, updatedAt: Timestamp.now()},
    {merge: true},
  );

  await cols.vipPurchases.add({
    uid, tier, method: "coins", coins: price,
    expiresAt, createdAt: Timestamp.now(),
  });

  await sendUserNotification(uid, {
    type: "vip",
    title: `VIP ${tier} activated 👑`,
    body: `Enjoy ${ECONOMY.vipMultipliers[tier]}× earnings for ${ECONOMY.vipDurationDays} days.`,
    deeplink: "/vip",
  });

  return {tier, expiresAt: expiresAt.toMillis()};
});

/**
 * Verifies a real-money subscription with Google Play and grants the tier.
 * Fails CLOSED — an unverifiable receipt is never credited, and the purchase
 * token is recorded so the same receipt cannot be replayed on another account.
 */
export const verifyVipPurchase = onCall(CALLABLE_OPTS, async (req) => {
  const uid = requireAuth(req);
  await assertAccountActive(uid);
  await rateLimit(uid, "vip_verify", 20, 3600);

  const productId = String(req.data?.productId ?? "");
  const purchaseToken = String(req.data?.purchaseToken ?? "");
  const tier = PRODUCT_TIERS[productId];
  if (!tier || !purchaseToken) {
    throw new HttpsError("invalid-argument", "Invalid purchase.");
  }

  // One receipt, one account — reject a token already bound to someone else.
  const tokenRef = cols.vipPurchases.doc(
    Buffer.from(purchaseToken).toString("base64url").slice(0, 400),
  );
  const existing = await tokenRef.get();
  if (existing.exists && existing.data()?.uid !== uid) {
    throw new HttpsError("permission-denied", "This purchase belongs to another account.");
  }

  const result = await verifyPlaySubscription(productId, purchaseToken);
  if (!result.valid) {
    throw new HttpsError("failed-precondition", "This subscription is not active.");
  }

  const expiresAt = Timestamp.fromMillis(result.expiryMillis);
  await userDoc(uid).set(
    {vipLevel: tier, vipExpiresAt: expiresAt, updatedAt: Timestamp.now()},
    {merge: true},
  );

  await tokenRef.set({
    uid, tier, method: "play", productId,
    orderId: result.orderId ?? null,
    autoRenewing: result.autoRenewing,
    expiresAt, createdAt: Timestamp.now(),
  }, {merge: true});

  await sendUserNotification(uid, {
    type: "vip",
    title: `VIP ${tier} activated 👑`,
    body: `Enjoy ${ECONOMY.vipMultipliers[tier]}× earnings.`,
    deeplink: "/vip",
  });

  return {tier, expiresAt: expiresAt.toMillis()};
});

/**
 * Flat once-per-UTC-day bonus for active VIP members, on top of the earn-rate
 * multiplier. A lapsed subscription simply has no entry in the table.
 */
export const claimVipDailyBonus = onCall(CALLABLE_OPTS, async (req) => {
  const uid = requireAuth(req);
  await assertAccountActive(uid);

  const snap = await userDoc(uid).get();
  const user = snap.data() ?? {};
  const vip = effectiveVipLevel(user);
  const coins = ECONOMY.vipDailyBonusCoins[vip];
  if (!coins) {
    throw new HttpsError("failed-precondition", "VIP membership required.");
  }

  const last = (user.lastVipBonusAt as FirebaseFirestore.Timestamp | undefined)?.toDate();
  if (last && isSameUtcDay(last, new Date())) {
    throw new HttpsError("failed-precondition", "Already claimed today.");
  }

  await userDoc(uid).set(
    {lastVipBonusAt: Timestamp.now(), updatedAt: Timestamp.now()},
    {merge: true},
  );

  const balance = await creditWallet({
    uid,
    amount: coins,
    type: "vip_bonus",
    title: `VIP ${vip} daily bonus`,
    metadata: {vip},
  });

  await auditLog(uid, "vip_daily_bonus", {vip, coins});
  return {coins, balance, vip};
});
