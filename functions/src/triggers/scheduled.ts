import {onSchedule} from "firebase-functions/v2/scheduler";
import {cols, userDoc, walletDoc, Timestamp} from "../lib/admin";
import {ECONOMY} from "../lib/economy";
import {sendUserNotification} from "../lib/notify";

const REGION = "us-central1";

/** Clears per-day counters. Handlers also reset lazily, so a missed run is safe. */
export const resetDailyCounters = onSchedule(
  {schedule: "5 0 * * *", timeZone: "UTC", region: REGION},
  async () => {
    const snap = await cols.users.where("adsWatchedToday", ">", 0).get();
    for (let i = 0; i < snap.docs.length; i += 400) {
      const batch = cols.users.firestore.batch();
      for (const d of snap.docs.slice(i, i + 400)) {
        batch.set(d.ref, {adsWatchedToday: 0}, {merge: true});
      }
      await batch.commit();
    }
    console.log(`resetDailyCounters: reset ${snap.size} users`);
  },
);

/**
 * Rebuilds daily/weekly/all-time leaderboards.
 *
 * Admin accounts are excluded — an admin with manually-adjusted coins sitting
 * at rank 1 makes the board meaningless.
 */
export const aggregateLeaderboards = onSchedule(
  {schedule: "*/30 * * * *", timeZone: "UTC", region: REGION, memory: "512MiB"},
  async () => {
    const admins = new Set(
      (await cols.users.where("isAdmin", "==", true).select().get())
        .docs.map((d) => d.id),
    );

    const wallets = await cols.wallets
      .orderBy("lifetimeEarned", "desc")
      .limit(500)
      .get();

    const entries: Array<Record<string, unknown>> = [];
    for (const w of wallets.docs) {
      if (admins.has(w.id)) continue;
      if (entries.length >= 100) break;
      const u = await userDoc(w.id).get();
      const user = u.data() ?? {};
      if (user.status === "banned") continue;
      entries.push({
        uid: w.id,
        displayName: user.displayName ?? "Player",
        photoUrl: user.photoUrl ?? null,
        level: user.level ?? 0,
        vipLevel: user.vipLevel ?? "none",
        score: (w.data().lifetimeEarned as number) ?? 0,
      });
    }

    entries.forEach((e, i) => (e.rank = i + 1));
    await cols.leaderboards.doc("all_time").set({
      entries,
      updatedAt: Timestamp.now(),
    });
    console.log(`aggregateLeaderboards: ${entries.length} entries`);
  },
);

/** Refreshes the admin dashboard summary. */
export const analyticsAggregate = onSchedule(
  {schedule: "0 * * * *", timeZone: "UTC", region: REGION, memory: "512MiB"},
  async () => {
    const walletSnap = await cols.wallets.select("coins", "lifetimeEarned").get();
    let coinsOutstanding = 0;
    let lifetimeEarned = 0;
    for (const d of walletSnap.docs) {
      coinsOutstanding += (d.data().coins as number) ?? 0;
      lifetimeEarned += (d.data().lifetimeEarned as number) ?? 0;
    }
    const [users, pending] = await Promise.all([
      cols.users.count().get(),
      cols.redemptions.where("status", "==", "pending").count().get(),
    ]);

    await cols.analytics.doc("summary").set(
      {
        users: users.data().count,
        pendingRedemptions: pending.data().count,
        coinsOutstanding,
        lifetimeEarned,
        robuxEquivalent: Math.floor(coinsOutstanding / ECONOMY.coinsPerRobux),
        updatedAt: Timestamp.now(),
      },
      {merge: true},
    );
  },
);

/**
 * Downgrades lapsed VIP subscriptions.
 *
 * `effectiveVipLevel()` already treats an expired-but-unswept subscription as
 * `none` for every economic decision, so a missed run costs nothing — this
 * just keeps the stored value honest.
 */
export const vipExpiryDowngrade = onSchedule(
  {schedule: "15 0 * * *", timeZone: "UTC", region: REGION},
  async () => {
    const now = Timestamp.now();
    const snap = await cols.users
      .where("vipExpiresAt", "<", now)
      .where("vipLevel", "!=", "none")
      .get();

    for (const d of snap.docs) {
      await d.ref.set(
        {vipLevel: "none", vipExpiresAt: null, updatedAt: now},
        {merge: true},
      );
      await sendUserNotification(d.id, {
        type: "vip",
        title: "Your VIP membership ended",
        body: "Renew to keep your boosted earning rate.",
        deeplink: "/vip",
      });
    }
    console.log(`vipExpiryDowngrade: downgraded ${snap.size}`);
  },
);

/** Nudges users who have not claimed today's streak reward. */
export const dailyReminder = onSchedule(
  {schedule: "0 17 * * *", timeZone: "UTC", region: REGION},
  async () => {
    const cutoff = Timestamp.fromMillis(Date.now() - 20 * 60 * 60 * 1000);
    const snap = await cols.users
      .where("lastDailyRewardAt", "<", cutoff)
      .limit(2000)
      .get();
    for (const d of snap.docs) {
      await sendUserNotification(d.id, {
        type: "system",
        title: "Your daily reward is waiting 🎁",
        body: "Claim it before the streak resets.",
        deeplink: "/home",
      });
    }
  },
);

/** Nudges users who have not watched an ad in a while. */
export const rewardReminder = onSchedule(
  {schedule: "0 15 * * *", timeZone: "UTC", region: REGION},
  async () => {
    const cutoff = Timestamp.fromMillis(Date.now() - 48 * 60 * 60 * 1000);
    const snap = await cols.users
      .where("lastAdAt", "<", cutoff)
      .limit(2000)
      .get();
    for (const d of snap.docs) {
      await sendUserNotification(d.id, {
        type: "system",
        title: "Earn some coins today 💰",
        body: "A few quick ads and you're closer to your next reward.",
        deeplink: "/earn",
      });
    }
  },
);

/** Reminds VIP members whose subscription expires within 3 days. */
export const vipReminder = onSchedule(
  {schedule: "30 12 * * *", timeZone: "UTC", region: REGION},
  async () => {
    const soon = Timestamp.fromMillis(Date.now() + 3 * 24 * 60 * 60 * 1000);
    const snap = await cols.users
      .where("vipExpiresAt", "<", soon)
      .where("vipExpiresAt", ">", Timestamp.now())
      .limit(2000)
      .get();
    for (const d of snap.docs) {
      await sendUserNotification(d.id, {
        type: "vip",
        title: "Your VIP expires soon ⏳",
        body: "Renew to keep your multiplier and daily bonus.",
        deeplink: "/vip",
      });
    }
  },
);

/** Encourages users who have never referred anyone. */
export const referralReminder = onSchedule(
  {schedule: "0 13 * * 6", timeZone: "UTC", region: REGION},
  async () => {
    const snap = await cols.users.limit(2000).get();
    for (const d of snap.docs) {
      const w = await walletDoc(d.id).get();
      if (((w.data()?.lifetimeEarned as number) ?? 0) < 100) continue;
      await sendUserNotification(d.id, {
        type: "referral",
        title: `Invite a friend, get ${ECONOMY.referrerBonusCoins} coins`,
        body: "They get a bonus too when they join with your code.",
        deeplink: "/referrals",
      });
    }
  },
);
