import * as functionsV1 from "firebase-functions/v1";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {auth, cols, userDoc, walletDoc, subcols, Timestamp} from "../lib/admin";
import {ECONOMY} from "../lib/economy";
import {creditWallet} from "../lib/wallet";
import {sendUserNotification} from "../lib/notify";

/**
 * Provisions the user + wallet documents on sign-up.
 *
 * Auth triggers only exist in the v1 SDK, so this stays on v1 while everything
 * else is v2 — that is deliberate, not an oversight.
 */
export const onUserCreated = functionsV1.auth.user().onCreate(async (user) => {
  const uid = user.uid;
  const referralCode = uid.slice(0, 6).toUpperCase();

  await userDoc(uid).set(
    {
      uid,
      email: user.email ?? null,
      displayName: user.displayName ?? null,
      photoUrl: user.photoURL ?? null,
      phoneNumber: user.phoneNumber ?? null,
      status: "active",
      vipLevel: "none",
      vipExpiresAt: null,
      xp: 0,
      level: 0,
      dailyStreak: 0,
      adsWatchedToday: 0,
      referralCode,
      referredBy: null,
      isAdmin: false,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    },
    {merge: true},
  );

  await walletDoc(uid).set(
    {
      uid,
      coins: 0,
      lifetimeEarned: 0,
      lifetimeSpent: 0,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    },
    {merge: true},
  );

  await sendUserNotification(uid, {
    type: "system",
    title: "Welcome to Robux Box 🎁",
    body: "Watch ads and complete offers to start earning coins.",
    deeplink: "/earn",
  });
});

/**
 * Pays out referral bonuses once — the first time a profile gains a
 * `referredBy` value. Guarded by `referralRewarded` so re-writing the field
 * can't be used to farm the bonus.
 */
export const applyReferralOnProfile = onDocumentUpdated(
  {document: "users/{uid}", region: "us-central1"},
  async (event) => {
    const before = event.data?.before.data() ?? {};
    const after = event.data?.after.data() ?? {};
    const uid = event.params.uid as string;

    const code = after.referredBy as string | undefined;
    if (!code) return;
    if (before.referredBy === after.referredBy) return;
    if (after.referralRewarded === true) return;

    const refSnap = await cols.users
      .where("referralCode", "==", code)
      .limit(1)
      .get();
    if (refSnap.empty) return;

    const referrerUid = refSnap.docs[0].id;
    if (referrerUid === uid) return; // no self-referral

    await userDoc(uid).set(
      {referralRewarded: true, updatedAt: Timestamp.now()},
      {merge: true},
    );

    await creditWallet({
      uid,
      amount: ECONOMY.refereeBonusCoins,
      type: "referral",
      title: "Referral welcome bonus",
      referenceId: referrerUid,
    });

    await creditWallet({
      uid: referrerUid,
      amount: ECONOMY.referrerBonusCoins,
      type: "referral",
      title: "Friend joined with your code",
      referenceId: uid,
    });

    await sendUserNotification(referrerUid, {
      type: "referral",
      title: "A friend joined! 🎉",
      body: `You earned ${ECONOMY.referrerBonusCoins} coins.`,
      deeplink: "/referrals",
    });
  },
);

/** Cleans up a deleted account's data. */
export const onUserDeleted = functionsV1.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const batch = cols.users.firestore.batch();
  batch.delete(userDoc(uid));
  batch.delete(walletDoc(uid));
  await batch.commit();

  for (const sub of [subcols.transactions(uid), subcols.devices(uid),
    subcols.notifications(uid), subcols.achievements(uid)]) {
    const snap = await sub.limit(500).get();
    if (snap.empty) continue;
    const b = cols.users.firestore.batch();
    snap.docs.forEach((d) => b.delete(d.ref));
    await b.commit();
  }

  try {
    await auth.revokeRefreshTokens(uid);
  } catch {
    // The Auth record is already gone at this point — nothing to revoke.
  }
});
