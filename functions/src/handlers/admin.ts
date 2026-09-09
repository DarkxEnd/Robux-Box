import {onCall, HttpsError} from "firebase-functions/v2/https";
import {auth, cols, userDoc, walletDoc, subcols, Timestamp} from "../lib/admin";
import {ECONOMY, cumulativeXpForLevel} from "../lib/economy";
import {creditWallet, debitWallet} from "../lib/wallet";
import {
  CALLABLE_OPTS,
  auditLog,
  requireAdmin,
  requireAuth,
} from "../lib/security";
import {sendUserNotification} from "../lib/notify";

/**
 * Grants/revokes the admin claim.
 *
 * Bootstrapping: the very first admin can claim it themselves if their email is
 * listed in `ADMIN_BOOTSTRAP_EMAIL`. Remove that env var once the first admin
 * exists — otherwise anyone who signs up with that address can self-promote.
 */
export const setAdminClaim = onCall(CALLABLE_OPTS, async (req) => {
  const callerUid = requireAuth(req);
  const targetUid = String(req.data?.uid ?? callerUid);
  const makeAdmin = req.data?.admin !== false;

  const isAdmin = req.auth?.token?.admin === true;
  if (!isAdmin) {
    const bootstrap = (process.env.ADMIN_BOOTSTRAP_EMAIL ?? "")
        .split(",")
        .map((e) => e.trim().toLowerCase())
        .filter(Boolean);
    const email = String(req.auth?.token?.email ?? "").toLowerCase();
    const allowed = email && bootstrap.includes(email) && targetUid === callerUid;
    if (!allowed) {
      throw new HttpsError("permission-denied", "Admin privileges required.");
    }
  }

  await auth.setCustomUserClaims(targetUid, {admin: makeAdmin});
  await userDoc(targetUid).set(
      {isAdmin: makeAdmin, updatedAt: Timestamp.now()},
      {merge: true},
  );
  await auditLog(callerUid, "set_admin_claim", {targetUid, admin: makeAdmin});
  return {ok: true, uid: targetUid, admin: makeAdmin};
});

/** Admin: manual coin adjustment, positive or negative, always audited. */
export const adjustCoins = onCall(CALLABLE_OPTS, async (req) => {
  const actor = requireAdmin(req);
  const uid = String(req.data?.uid ?? "");
  const amount = Number(req.data?.amount ?? 0);
  const reason = String(req.data?.reason ?? "Admin adjustment");
  if (!uid || !Number.isFinite(amount) || amount === 0) {
    throw new HttpsError("invalid-argument", "Provide a uid and non-zero amount.");
  }

  const balance = amount > 0 ?
    await creditWallet({
      uid, amount, type: "admin_adjust", title: reason,
      metadata: {actor, reason},
    }) :
    await debitWallet({
      uid, amount: Math.abs(amount), type: "admin_adjust", title: reason,
      metadata: {actor, reason},
    });

  await auditLog(actor, "adjust_coins", {uid, amount, reason});
  await sendUserNotification(uid, {
    type: "system",
    title: amount > 0 ? "Coins added" : "Coins adjusted",
    body: reason,
    deeplink: "/wallet",
  });

  return {ok: true, balance};
});

/** Admin: ban/restrict/reactivate an account, mirrored into Firebase Auth. */
export const setAccountStatus = onCall(CALLABLE_OPTS, async (req) => {
  const actor = requireAdmin(req);
  const uid = String(req.data?.uid ?? "");
  const status = String(req.data?.status ?? "active");
  const reason = String(req.data?.reason ?? "");
  if (!["active", "restricted", "banned"].includes(status)) {
    throw new HttpsError("invalid-argument", "Invalid status.");
  }

  await userDoc(uid).set(
      {status, statusReason: reason || null, updatedAt: Timestamp.now()},
      {merge: true},
  );
  // Disabling the Auth user too stops an existing session from continuing to
  // hold a valid ID token until it expires.
  await auth.updateUser(uid, {disabled: status === "banned"});
  await auditLog(actor, "set_account_status", {uid, status, reason});
  return {ok: true, status};
});

/** Admin: grants a VIP tier with no expiry (a permanent comp). */
export const setVipLevel = onCall(CALLABLE_OPTS, async (req) => {
  const actor = requireAdmin(req);
  const uid = String(req.data?.uid ?? "");
  const level = String(req.data?.level ?? "none");
  if (!(level in ECONOMY.vipRankOf)) {
    throw new HttpsError("invalid-argument", "Unknown VIP level.");
  }

  await userDoc(uid).set(
      {vipLevel: level, vipExpiresAt: null, updatedAt: Timestamp.now()},
      {merge: true},
  );
  await auditLog(actor, "set_vip_level", {uid, level});
  await sendUserNotification(uid, {
    type: "vip",
    title: level === "none" ? "VIP removed" : `VIP ${level} granted 👑`,
    body: level === "none" ?
      "Your VIP membership has ended." :
      "Enjoy your upgraded earning rate.",
    deeplink: "/vip",
  });
  return {ok: true, level};
});

/** Admin: sets a user's level directly, deriving the matching XP floor. */
export const setUserLevel = onCall(CALLABLE_OPTS, async (req) => {
  const actor = requireAdmin(req);
  const uid = String(req.data?.uid ?? "");
  const level = Math.max(0, Math.floor(Number(req.data?.level ?? 0)));
  if (!uid) throw new HttpsError("invalid-argument", "Provide a uid.");

  await userDoc(uid).set(
      {level, xp: cumulativeXpForLevel(level), updatedAt: Timestamp.now()},
      {merge: true},
  );
  await auditLog(actor, "set_user_level", {uid, level});
  return {ok: true, level};
});

/** Admin: creates or updates a promo code. */
export const upsertPromocode = onCall(CALLABLE_OPTS, async (req) => {
  const actor = requireAdmin(req);
  const code = String(req.data?.code ?? "").trim().toUpperCase();
  if (!code) throw new HttpsError("invalid-argument", "Provide a code.");

  const expiresAtMillis = Number(req.data?.expiresAt ?? 0);
  await cols.promocodes.doc(code).set(
      {
        rewardCoins: Number(req.data?.rewardCoins ?? 0),
        maxRedemptions: Number(req.data?.maxRedemptions ?? -1),
        perUserLimit: Number(req.data?.perUserLimit ?? 1),
        isActive: req.data?.isActive !== false,
        expiresAt: expiresAtMillis ? Timestamp.fromMillis(expiresAtMillis) : null,
        updatedAt: Timestamp.now(),
      },
      {merge: true},
  );

  await auditLog(actor, "upsert_promocode", {code});
  return {ok: true, code};
});

/**
 * Admin: fans a notification out to every matching user.
 *
 * Writes are chunked into batches of 400 (Firestore's limit is 500) so a large
 * audience doesn't blow the batch size — "Everyone" silently delivering to
 * nobody was a real bug here once.
 */
export const broadcastNotification = onCall(
    {...CALLABLE_OPTS, timeoutSeconds: 540, memory: "512MiB"},
    async (req) => {
      const actor = requireAdmin(req);
      const title = String(req.data?.title ?? "").trim();
      const body = String(req.data?.body ?? "").trim();
      const audience = String(req.data?.audience ?? "all");
      const deeplink = String(req.data?.deeplink ?? "");
      if (!title || !body) {
        throw new HttpsError("invalid-argument", "Title and body are required.");
      }

      let query: FirebaseFirestore.Query = cols.users;
      if (audience === "vip") {
        query = query.where("vipLevel", "in", ["bronze", "silver", "gold", "diamond"]);
      } else if (audience === "non_vip") {
        query = query.where("vipLevel", "==", "none");
      }

      const snap = await query.select().get();
      const uids = snap.docs.map((d) => d.id);

      let written = 0;
      for (let i = 0; i < uids.length; i += 400) {
        const batch = cols.users.firestore.batch();
        for (const uid of uids.slice(i, i + 400)) {
          batch.set(subcols.notifications(uid).doc(), {
            type: "system",
            title,
            body,
            deeplink: deeplink || null,
            read: false,
            createdAt: Timestamp.now(),
          });
        }
        await batch.commit();
        written += Math.min(400, uids.length - i);
      }

      await auditLog(actor, "broadcast", {audience, title, recipients: written});
      return {ok: true, recipients: written};
    },
);

/** Admin: recomputes the dashboard analytics document on demand. */
export const refreshAnalytics = onCall(
    {...CALLABLE_OPTS, timeoutSeconds: 300},
    async (req) => {
      const actor = requireAdmin(req);

      const [users, wallets, pending, completions] = await Promise.all([
        cols.users.count().get(),
        cols.wallets.count().get(),
        cols.redemptions.where("status", "==", "pending").count().get(),
        cols.offerCompletions.count().get(),
      ]);

      const walletSnap = await cols.wallets.select("coins", "lifetimeEarned").get();
      let coinsOutstanding = 0;
      let lifetimeEarned = 0;
      for (const d of walletSnap.docs) {
        coinsOutstanding += (d.data().coins as number) ?? 0;
        lifetimeEarned += (d.data().lifetimeEarned as number) ?? 0;
      }

      const summary = {
        users: users.data().count,
        wallets: wallets.data().count,
        pendingRedemptions: pending.data().count,
        offerCompletions: completions.data().count,
        coinsOutstanding,
        lifetimeEarned,
        robuxEquivalent: Math.floor(coinsOutstanding / ECONOMY.coinsPerRobux),
        updatedAt: Timestamp.now(),
      };

      await cols.analytics.doc("summary").set(summary, {merge: true});
      await auditLog(actor, "refresh_analytics", {});
      return summary;
    },
);

/** Admin: paginated user list for the dashboard. */
export const listUsers = onCall(CALLABLE_OPTS, async (req) => {
  requireAdmin(req);
  const limit = Math.min(Math.max(Number(req.data?.limit ?? 25), 1), 100);
  const startAfter = String(req.data?.startAfter ?? "");

  let q = cols.users.orderBy("createdAt", "desc").limit(limit);
  if (startAfter) {
    const cursor = await cols.users.doc(startAfter).get();
    if (cursor.exists) q = q.startAfter(cursor);
  }

  const snap = await q.get();
  const items = await Promise.all(
      snap.docs.map(async (d) => {
        const w = await walletDoc(d.id).get();
        return {
          uid: d.id,
          ...d.data(),
          coins: (w.data()?.coins as number) ?? 0,
        };
      }),
  );

  return {items, nextCursor: snap.docs.at(-1)?.id ?? null};
});
