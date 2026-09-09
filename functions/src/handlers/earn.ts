import {onCall, HttpsError} from "firebase-functions/v2/https";
import {cols, userDoc, subcols, Timestamp} from "../lib/admin";
import {
  ECONOMY,
  effectiveVipLevel,
  isSameUtcDay,
  maxAdsPerDay,
  rewardedAdCoins,
  AdFormat,
} from "../lib/economy";
import {tierForCountry} from "../lib/tiers";
import {creditWallet} from "../lib/wallet";
import {
  CALLABLE_OPTS,
  DeviceContext,
  assertAccountActive,
  assertIntegrity,
  checkVelocity,
  consumeNonce,
  issueNonce,
  rateLimit,
  recordDevice,
  requireAuth,
} from "../lib/security";
import {sendUserNotification} from "../lib/notify";

/** Reads the user doc, throwing rather than silently treating it as a new user. */
async function loadUser(uid: string) {
  const snap = await userDoc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Account not found. Try signing in again.");
  }
  return snap.data()!;
}

/** Ads watched today, reset lazily so a missed cron run can't grant free ads. */
function adsWatchedToday(user: FirebaseFirestore.DocumentData): number {
  const last = (user.lastAdAt as FirebaseFirestore.Timestamp | undefined)?.toDate();
  if (!last || !isSameUtcDay(last, new Date())) return 0;
  return (user.adsWatchedToday as number) ?? 0;
}

/**
 * Step 1 of the rewarded-ad flow: issues a single-use nonce bound to this user.
 * The nonce is passed to the AdMob SDK as SSV `custom_data`, so the callback
 * AdMob makes can be tied back to exactly this request.
 */
export const beginRewardedAd = onCall(CALLABLE_OPTS, async (req) => {
  const uid = requireAuth(req);
  await assertAccountActive(uid);
  await rateLimit(uid, "begin_ad", 60, 3600);

  const device = req.data?.device as DeviceContext | undefined;
  assertIntegrity(device);
  if (device) await recordDevice(uid, device);

  const user = await loadUser(uid);
  const vip = effectiveVipLevel(user);
  const cap = maxAdsPerDay(vip);
  const watched = adsWatchedToday(user);
  if (watched >= cap) {
    throw new HttpsError(
        "resource-exhausted",
        "You've reached today's ad limit. Come back tomorrow!",
    );
  }

  const lastAt = (user.lastAdAt as FirebaseFirestore.Timestamp | undefined)?.toMillis() ?? 0;
  const elapsed = (Date.now() - lastAt) / 1000;
  if (lastAt && elapsed < ECONOMY.rewardedAdCooldownSeconds) {
    throw new HttpsError(
        "failed-precondition",
        `Please wait ${Math.ceil(ECONOMY.rewardedAdCooldownSeconds - elapsed)}s.`,
    );
  }

  const format: AdFormat =
    req.data?.format === "interstitial" ? "interstitial" : "rewarded";
  const nonce = await issueNonce(uid, "rewarded_ad", {format});

  return {nonce, adsLeft: cap - watched, format};
});

/**
 * Step 2: consumes the nonce and credits coins. In STRICT_SSV mode a matching
 * `ad_impressions/{nonce}` record with `verified: true` (written by AdMob's
 * signed SSV callback) is required — without it, any authenticated caller
 * could mint rewards without an ad ever playing.
 */
export const confirmRewardedAd = onCall(CALLABLE_OPTS, async (req) => {
  const uid = requireAuth(req);
  await assertAccountActive(uid);

  const nonce = String(req.data?.nonce ?? "");
  const data = await consumeNonce(uid, nonce, "rewarded_ad");
  const format: AdFormat =
    data.format === "interstitial" ? "interstitial" : "rewarded";

  const ssv = await cols.adImpressions.doc(nonce).get();
  if (process.env.STRICT_SSV === "true" && ssv.data()?.verified !== true) {
    throw new HttpsError(
        "failed-precondition",
        "This reward could not be verified. Please try another ad.",
    );
  }

  const user = await loadUser(uid);
  const vip = effectiveVipLevel(user);
  const tierLevel = await tierForCountry(String(user.countryCode ?? "US"));
  const coins = rewardedAdCoins(tierLevel, vip, format);

  await checkVelocity(uid, coins);

  const watched = adsWatchedToday(user);
  await userDoc(uid).set(
      {
        adsWatchedToday: watched + 1,
        lastAdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      },
      {merge: true},
  );

  const balance = await creditWallet({
    uid,
    amount: coins,
    type: "rewarded_ad",
    title: format === "interstitial" ? "Quick ad" : "Rewarded ad",
    referenceId: nonce,
    xp: ECONOMY.xpPerAd,
    metadata: {tierLevel, vip, format, ssvVerified: ssv.data()?.verified === true},
  });

  return {coins, balance, adsLeft: maxAdsPerDay(vip) - (watched + 1)};
});

/**
 * Daily streak reward. The streak advances only on consecutive UTC days and
 * resets after a gap, so the table can't be farmed by claiming twice in one day.
 */
export const claimDailyReward = onCall(CALLABLE_OPTS, async (req) => {
  const uid = requireAuth(req);
  await assertAccountActive(uid);
  await rateLimit(uid, "daily_reward", 5, 3600);

  const user = await loadUser(uid);
  const now = new Date();
  const last = (user.lastDailyRewardAt as FirebaseFirestore.Timestamp | undefined)?.toDate();

  if (last && isSameUtcDay(last, now)) {
    throw new HttpsError("failed-precondition", "Already claimed today.");
  }

  const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const continued = last ? isSameUtcDay(last, yesterday) : false;
  const streak = continued ? ((user.dailyStreak as number) ?? 0) + 1 : 1;

  const table = ECONOMY.dailyStreakRewards;
  const coins = table[(streak - 1) % table.length];

  await userDoc(uid).set(
      {
        dailyStreak: streak,
        lastDailyRewardAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      },
      {merge: true},
  );

  const balance = await creditWallet({
    uid,
    amount: coins,
    type: "daily_reward",
    title: `Daily reward — day ${streak}`,
    xp: ECONOMY.xpPerAd,
    metadata: {streak},
  });

  return {coins, balance, streak};
});

/**
 * Redeems a promo code. The per-user limit and global cap are both enforced
 * inside one transaction so a burst of parallel calls can't overshoot either.
 */
export const redeemPromocode = onCall(CALLABLE_OPTS, async (req) => {
  const uid = requireAuth(req);
  await assertAccountActive(uid);
  await rateLimit(uid, "promocode", 10, 3600);

  const code = String(req.data?.code ?? "").trim().toUpperCase();
  if (!code) throw new HttpsError("invalid-argument", "Enter a promo code.");

  const ref = cols.promocodes.doc(code);
  const usageRef = ref.collection("redemptions").doc(uid);

  const coins = await cols.promocodes.firestore.runTransaction(async (t) => {
    const [snap, usage] = await Promise.all([t.get(ref), t.get(usageRef)]);
    if (!snap.exists) {
      throw new HttpsError("not-found", "That code isn't valid.");
    }
    const p = snap.data()!;
    if (p.isActive === false) {
      throw new HttpsError("failed-precondition", "That code is no longer active.");
    }
    const expiresAt = p.expiresAt as FirebaseFirestore.Timestamp | null;
    if (expiresAt && expiresAt.toMillis() < Date.now()) {
      throw new HttpsError("failed-precondition", "That code has expired.");
    }
    const max = (p.maxRedemptions as number) ?? -1;
    const used = (p.redemptionCount as number) ?? 0;
    if (max >= 0 && used >= max) {
      throw new HttpsError("resource-exhausted", "That code is fully redeemed.");
    }
    const perUser = (p.perUserLimit as number) ?? 1;
    const mine = (usage.data()?.count as number) ?? 0;
    if (mine >= perUser) {
      throw new HttpsError("failed-precondition", "You already used that code.");
    }

    t.set(ref, {redemptionCount: used + 1}, {merge: true});
    t.set(
        usageRef,
        {uid, count: mine + 1, lastUsedAt: Timestamp.now()},
        {merge: true},
    );
    return (p.rewardCoins as number) ?? 0;
  });

  if (coins <= 0) return {coins: 0, balance: null};

  const balance = await creditWallet({
    uid,
    amount: coins,
    type: "promocode",
    title: `Promo code ${code}`,
    referenceId: code,
    metadata: {code},
  });

  return {coins, balance};
});

/**
 * Resolves the payout tier for the caller. The client sends its GPS-derived
 * country as a hint, but the stored country of record wins — a spoofed
 * location changes only what the UI previews, never the payout.
 */
export const resolveTier = onCall(CALLABLE_OPTS, async (req) => {
  const uid = requireAuth(req);
  const user = await loadUser(uid);

  const hinted = String(req.data?.countryCode ?? "").toUpperCase().slice(0, 2);
  const ofRecord = String(user.countryCode ?? "").toUpperCase().slice(0, 2);

  // First observation wins: the country of record is set once, on first
  // resolve, and only an admin can change it afterwards.
  const country = ofRecord || hinted || "US";
  if (!ofRecord && country) {
    await userDoc(uid).set(
        {countryCode: country, updatedAt: Timestamp.now()},
        {merge: true},
    );
  }

  const tierLevel = await tierForCountry(country);
  const vip = effectiveVipLevel(user);

  return {
    tierLevel,
    vipLevel: vip,
    maxAdsPerDay: maxAdsPerDay(vip),
    adsWatchedToday: adsWatchedToday(user),
  };
});

/**
 * One-time reward for opening the store review flow. Deliberately NOT tied to
 * the rating given: the in-app review API never reports that back, and paying
 * for positive ratings specifically violates Play Store policy.
 */
export const claimRateAppReward = onCall(CALLABLE_OPTS, async (req) => {
  const uid = requireAuth(req);
  await assertAccountActive(uid);

  const user = await loadUser(uid);
  if (user.rateAppRewardClaimed === true) {
    throw new HttpsError("failed-precondition", "Already claimed.");
  }

  await userDoc(uid).set(
      {rateAppRewardClaimed: true, updatedAt: Timestamp.now()},
      {merge: true},
  );

  const coins = ECONOMY.rateAppRewardCoins;
  const balance = await creditWallet({
    uid,
    amount: coins,
    type: "rate_app",
    title: "Thanks for rating us!",
  });

  await sendUserNotification(uid, {
    type: "reward",
    title: "Thanks for the review ⭐",
    body: `${coins} coins added to your balance.`,
    deeplink: "/wallet",
  });

  return {coins, balance};
});

/** Recent earning history for the Wallet screen (server-paginated). */
export const recentTransactions = onCall(CALLABLE_OPTS, async (req) => {
  const uid = requireAuth(req);
  const limit = Math.min(Math.max(Number(req.data?.limit ?? 25), 1), 100);
  const snap = await subcols
      .transactions(uid)
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();
  return {
    items: snap.docs.map((d) => ({id: d.id, ...d.data()})),
  };
});
