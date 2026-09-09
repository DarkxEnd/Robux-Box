import {onCall, HttpsError} from "firebase-functions/v2/https";
import {cols, userDoc, Timestamp} from "../lib/admin";
import {effectiveVipLevel, vipRank} from "../lib/economy";
import {creditWallet, debitWallet} from "../lib/wallet";
import {
  CALLABLE_OPTS,
  assertAccountActive,
  auditLog,
  rateLimit,
  requireAdmin,
  requireAuth,
} from "../lib/security";
import {sendUserNotification, notifyAdmins} from "../lib/notify";

export type RedemptionStatus =
  | "pending"
  | "approved"
  | "paid"
  | "rejected"
  | "cancelled";

/**
 * Requests a redemption. Coins are debited immediately as a HOLD so the same
 * balance can't be spent twice while a request is queued; a rejection or
 * cancellation refunds them.
 */
export const requestRedemption = onCall(CALLABLE_OPTS, async (req) => {
  const uid = requireAuth(req);
  await assertAccountActive(uid);
  await rateLimit(uid, "redeem", 10, 3600);

  const rewardId = String(req.data?.rewardId ?? "");
  const destination = String(req.data?.destination ?? "").trim();
  if (!rewardId) throw new HttpsError("invalid-argument", "Pick a reward.");
  if (!destination) {
    throw new HttpsError(
        "invalid-argument",
        "Enter where the reward should be sent (e.g. your Roblox username).",
    );
  }

  const rSnap = await cols.rewards.doc(rewardId).get();
  if (!rSnap.exists) throw new HttpsError("not-found", "Reward unavailable.");
  const reward = rSnap.data()!;
  if (reward.isActive === false) {
    throw new HttpsError("failed-precondition", "That reward is not available.");
  }

  const uSnap = await userDoc(uid).get();
  const user = uSnap.data() ?? {};
  const vip = effectiveVipLevel(user);
  const minVip = (reward.minVipLevel as number) ?? 0;
  if (vipRank(vip) < minVip) {
    throw new HttpsError("permission-denied", "This reward is VIP-only.");
  }

  const stock = reward.stock as number | undefined;
  if (typeof stock === "number" && stock <= 0) {
    throw new HttpsError("resource-exhausted", "That reward is out of stock.");
  }

  const cost = (reward.coinCost as number) ?? 0;
  await debitWallet({
    uid,
    amount: cost,
    type: "redemption",
    title: `Redeem: ${reward.title ?? rewardId}`,
    referenceId: rewardId,
    metadata: {rewardId, destination},
  });

  const doc = await cols.redemptions.add({
    uid,
    rewardId,
    rewardTitle: reward.title ?? rewardId,
    kind: reward.kind ?? "robux",
    coinCost: cost,
    faceValue: reward.faceValue ?? null,
    currency: reward.currency ?? null,
    destination,
    status: "pending" as RedemptionStatus,
    // Gold/Diamond members are worked first — see docs/SECURITY.md §8.
    priority: vipRank(vip) >= 3 ? 1 : 0,
    vipLevel: vip,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });

  await sendUserNotification(uid, {
    type: "redemption",
    title: "Redemption requested ⏳",
    body: `We received your request for ${reward.title ?? "your reward"}.`,
    deeplink: "/redemptions",
  });
  await notifyAdmins(
      "New redemption request",
      `User ${uid} requested ${reward.title ?? rewardId} (${cost} coins).`,
  );

  return {id: doc.id, status: "pending"};
});

/** Cancels a still-pending request and refunds the held coins. */
export const cancelRedemption = onCall(CALLABLE_OPTS, async (req) => {
  const uid = requireAuth(req);
  const id = String(req.data?.id ?? "");
  const ref = cols.redemptions.doc(id);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Request not found.");

  const r = snap.data()!;
  if (r.uid !== uid) throw new HttpsError("permission-denied", "Not your request.");
  if (r.status !== "pending") {
    throw new HttpsError("failed-precondition", "This request is already being processed.");
  }

  await ref.set(
      {status: "cancelled", updatedAt: Timestamp.now()},
      {merge: true},
  );
  await creditWallet({
    uid,
    amount: (r.coinCost as number) ?? 0,
    type: "refund",
    title: `Refund: ${r.rewardTitle ?? "redemption"}`,
    referenceId: id,
    metadata: {redemptionId: id, reason: "cancelled_by_user"},
  });

  return {ok: true};
});

/** Admin: moves a request through approved → paid, or rejects with a refund. */
export const processRedemption = onCall(CALLABLE_OPTS, async (req) => {
  const actor = requireAdmin(req);
  const id = String(req.data?.id ?? "");
  const status = String(req.data?.status ?? "") as RedemptionStatus;
  const note = String(req.data?.note ?? "");

  if (!["approved", "paid", "rejected"].includes(status)) {
    throw new HttpsError("invalid-argument", "Invalid status.");
  }

  const ref = cols.redemptions.doc(id);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Request not found.");
  const r = snap.data()!;

  if (["paid", "rejected", "cancelled"].includes(r.status as string)) {
    throw new HttpsError("failed-precondition", "This request is already finalised.");
  }

  await ref.set(
      {
        status,
        adminNote: note || null,
        processedBy: actor,
        updatedAt: Timestamp.now(),
        ...(status === "paid" ? {paidAt: Timestamp.now()} : {}),
      },
      {merge: true},
  );

  if (status === "rejected") {
    await creditWallet({
      uid: r.uid as string,
      amount: (r.coinCost as number) ?? 0,
      type: "refund",
      title: `Refund: ${r.rewardTitle ?? "redemption"}`,
      referenceId: id,
      metadata: {redemptionId: id, reason: "rejected", note},
    });
  }

  const messages: Record<string, {title: string; body: string}> = {
    approved: {
      title: "Redemption approved ✅",
      body: "Your reward is being prepared.",
    },
    paid: {
      title: "Reward sent 🎉",
      body: `${r.rewardTitle ?? "Your reward"} has been delivered.`,
    },
    rejected: {
      title: "Redemption rejected",
      body: note || "Your coins have been refunded.",
    },
  };
  await sendUserNotification(r.uid as string, {
    type: "redemption",
    ...messages[status],
    deeplink: "/redemptions",
  });

  await auditLog(actor, "process_redemption", {id, status, note});
  return {ok: true, status};
});

/**
 * Admin: deletes a request. A still-pending one is refunded first so deleting
 * a queue entry can never quietly swallow a user's coins.
 */
export const deleteRedemption = onCall(CALLABLE_OPTS, async (req) => {
  const actor = requireAdmin(req);
  const id = String(req.data?.id ?? "");
  const ref = cols.redemptions.doc(id);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Request not found.");
  const r = snap.data()!;

  if (r.status === "pending") {
    await creditWallet({
      uid: r.uid as string,
      amount: (r.coinCost as number) ?? 0,
      type: "refund",
      title: `Refund: ${r.rewardTitle ?? "redemption"}`,
      referenceId: id,
      metadata: {redemptionId: id, reason: "deleted_by_admin"},
    });
  }

  await ref.delete();
  await auditLog(actor, "delete_redemption", {id, wasStatus: r.status});
  return {ok: true, refunded: r.status === "pending"};
});
