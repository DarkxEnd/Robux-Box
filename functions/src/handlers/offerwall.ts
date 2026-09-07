import * as crypto from "crypto";
import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import {cols, userDoc, Timestamp} from "../lib/admin";
import {ECONOMY} from "../lib/economy";
import {tierForCountry} from "../lib/tiers";
import {creditWallet} from "../lib/wallet";
import {
  requireAuth,
  flagFraud,
  secretsMatch,
  CALLABLE_OPTS,
} from "../lib/security";
import {sendUserNotification} from "../lib/notify";
import {verifyAdmobSignature} from "../lib/admobVerify";

// CPX Research (https://cpx-research.com) is the survey provider.
// Both directions below share one per-app secret from the CPX publisher
// dashboard (Apps → your app → "Secure Hash") — it never ships in the app.
const CPX_BASE_URL = "https://offers.cpx-research.com/index.php";

/** The offerwall providers the app can open. */
type OfferwallProvider = "cpx" | "cpalead" | "lootwalls";

function cpxSecureHashSecret(): string {
  return process.env.CPX_SECURE_HASH ?? "";
}

function md5(input: string): string {
  return crypto.createHash("md5").update(input).digest("hex");
}

/**
 * Builds the CPX Research wall URL, signed with md5(ext_user_id-secret) per
 * their docs so the signing secret never ships in the app.
 */
function cpxWallUrl(uid: string, email?: string, username?: string): string {
  const appId = process.env.OFFERWALL_APP_ID ?? "";
  const secret = cpxSecureHashSecret();
  if (!appId || !secret) {
    throw new HttpsError("failed-precondition", "Offerwall not configured.");
  }
  const params = new URLSearchParams({
    app_id: appId,
    ext_user_id: uid,
    secure_hash: md5(`${uid}-${secret}`),
  });
  if (email) params.set("email", email);
  if (username) params.set("username", username);
  return `${CPX_BASE_URL}?${params.toString()}`;
}

/**
 * Builds the CPAlead wall URL from the `CPALEAD_WALL_URL` template.
 *
 * CPAlead generates the wall/widget URL for you in their dashboard, and the
 * exact shape varies by widget type — so rather than hardcoding a format that
 * could silently drift, the whole URL is config: paste it verbatim and mark
 * where the user id goes with `{USER_ID}`. If the placeholder is missing the
 * uid is appended as `subid` (CPAlead's standard sub-id param), because a wall
 * opened without attribution completes offers that can never be credited.
 */
function cpaleadWallUrl(uid: string): string {
  const template = process.env.CPALEAD_WALL_URL ?? "";
  if (!template) {
    throw new HttpsError("failed-precondition", "Offerwall not configured.");
  }
  if (template.includes("{USER_ID}")) {
    return template.replace(/\{USER_ID\}/g, encodeURIComponent(uid));
  }
  const sep = template.includes("?") ? "&" : "?";
  return `${template}${sep}subid=${encodeURIComponent(uid)}`;
}

/**
 * Builds the Lootwalls wall URL. Unlike CPAlead's opaque template, Lootwalls'
 * own integration snippet is a plain, stable `?apiKey=<key>&userId=<id>` query
 * string, so it is built directly here instead of via a URL template env var.
 */
function lootwallsWallUrl(uid: string): string {
  const apiKey = process.env.LOOTWALLS_API_KEY ?? "";
  if (!apiKey) {
    throw new HttpsError("failed-precondition", "Offerwall not configured.");
  }
  const params = new URLSearchParams({apiKey, userId: uid});
  return `https://www.lootwalls.com/wall?${params.toString()}`;
}

/**
 * Returns a per-user offerwall URL for the caller, for whichever provider the
 * client asked for (defaults to CPX). Each provider's signing secret / wall
 * config lives only in Cloud Functions env, never in the app.
 */
export const getOfferwallUrl = onCall(CALLABLE_OPTS, async (req) => {
  const uid = requireAuth(req);
  const requested = String(req.data?.provider ?? "");
  const provider: OfferwallProvider =
    requested === "cpalead" || requested === "lootwalls" ? requested : "cpx";

  if (provider === "cpalead") {
    return {url: cpaleadWallUrl(uid), provider};
  }
  if (provider === "lootwalls") {
    return {url: lootwallsWallUrl(uid), provider};
  }
  const email = req.auth?.token?.email;
  const username = req.auth?.token?.name;
  return {
    url: cpxWallUrl(
        uid,
      email ? String(email) : undefined,
      username ? String(username) : undefined,
    ),
    provider,
  };
});

/**
 * Records a completed (or reversed) offerwall conversion and credits coins.
 * Shared by every provider's postback so they can't drift apart on the payout
 * maths, idempotency or reversal handling.
 *
 * [docId] namespaces the completion record per provider — CPX's records
 * predate multi-provider support and are keyed by the bare transaction id, so
 * that key must stay as-is or an old CPX transaction re-calling would look
 * new and double-credit.
 */
async function recordOfferCompletion(args: {
  docId: string;
  uid: string;
  transId: string;
  offerName: string;
  payoutUsd: number;
  isReversal: boolean;
}): Promise<{status: number; body: string}> {
  const {docId, uid, transId, offerName, payoutUsd, isReversal} = args;
  const compRef = cols.offerCompletions.doc(docId);
  const existing = await compRef.get();

  if (existing.exists) {
    const prev = existing.data()!;
    // Providers re-call the same transaction id with a reversal status once a
    // completed offer is later detected as fraud (CPX's docs say "usually
    // within 15-60 days"). Flag it for admin review — the coins may already
    // be spent, so this isn't auto-clawed-back from the wallet.
    if (isReversal && !prev.reversed) {
      await compRef.set(
          {reversed: true, reversedAt: Timestamp.now()},
          {merge: true},
      );
      await flagFraud(uid, "offerwall_reversed", {
        transId, coins: prev.coins ?? 0, payoutUsd,
      });
    }
    return {status: 200, body: "ok"}; // already processed either way
  }

  // Reported as canceled/reversed before ever being completed — nothing was
  // credited, so just record it.
  if (isReversal) {
    await compRef.set({
      uid, transId, offerName, payoutUsd, coins: 0,
      reversed: true, createdAt: Timestamp.now(),
    });
    return {status: 200, body: "ok"};
  }

  const uSnap = await userDoc(uid).get();
  if (!uSnap.exists) return {status: 404, body: "unknown user"};

  const user = uSnap.data()!;
  const country = String(user.countryCode ?? "US");
  const tierLevel = await tierForCountry(country);

  // Convert provider payout → coins with the user share (developer margin).
  const grossCoins = Math.round(payoutUsd * ECONOMY.coinsPerRobux * 10);
  const coins = Math.max(
      1,
      Math.round(grossCoins * ECONOMY.offerwallUserSharePercent *
      (tierLevel === 1 ? 1 : 0.9)),
  );

  await compRef.set({
    uid, transId, offerName, payoutUsd, coins, tierLevel, country,
    reversed: false, createdAt: Timestamp.now(), completedAt: Timestamp.now(),
  });

  await creditWallet({
    uid,
    amount: coins,
    type: "offerwall",
    title: offerName,
    referenceId: transId,
    xp: ECONOMY.xpPerOffer,
    metadata: {payoutUsd, tierLevel, country},
  });

  await sendUserNotification(uid, {
    type: "reward",
    title: "Offer completed 💰",
    body: `You earned ${coins} coins from ${offerName}!`,
    deeplink: "/wallet",
  });

  return {status: 200, body: "ok"};
}

/**
 * Server-to-server postback CPX Research calls when a survey/offer is
 * completed, screened-out, or later reversed as fraud. This is the ONLY
 * trusted signal that credits offerwall coins — the WebView cannot mint them.
 *
 * Security: verifies CPX's md5(trans_id-secret) hash, is idempotent per
 * transaction id, and applies the developer margin (user gets
 * `offerwallUserSharePercent` of the tier-adjusted value).
 *
 * Params CPX sends (see publisher dashboard → Postback Settings):
 *   status (1=completed, 2=canceled/reversed), trans_id, user_id, sub_id,
 *   sub_id_2, amount_local, amount_usd, offer_id, hash, ip_click
 */
export const offerwallPostback = onRequest(
    {region: "us-central1", cors: false},
    async (req, res) => {
      try {
        const q = {...req.query, ...req.body} as Record<string, string>;
        const uid = String(q.user_id ?? "");
        const transId = String(q.trans_id ?? "");
        const hash = String(q.hash ?? "");
        const status = String(q.status ?? "1");
        // `|| 0` guards a missing/garbled amount: NaN would otherwise flow into
        // the coin maths and Firestore rejects NaN, failing the whole postback.
        const payoutUsd = parseFloat(String(q.amount_usd ?? "0")) || 0;
        const offerId = String(q.offer_id ?? "");
        const offerName = offerId ? `CPX Survey #${offerId}` : "CPX Survey";

        if (!uid || !transId) {
          res.status(400).send("missing params");
          return;
        }

        // Verify CPX's signature: md5(trans_id-secret).
        if (!secretsMatch(hash, md5(`${transId}-${cpxSecureHashSecret()}`))) {
          await flagFraud(uid, "offerwall_bad_signature", {transId});
          res.status(403).send("bad signature");
          return;
        }

        const outcome = await recordOfferCompletion({
          docId: transId,
          uid,
          transId,
          offerName,
          payoutUsd,
          isReversal: status === "2",
        });
        res.status(outcome.status).send(outcome.body);
      } catch (e) {
        console.error("offerwallPostback error", e);
        res.status(500).send("error");
      }
    },
);

/**
 * Server-to-server postback CPAlead calls when an offer is completed. Like
 * CPX's, this is the ONLY trusted signal that credits CPAlead coins.
 *
 * Unlike CPX (whose postback shape is fixed by their docs), CPAlead's postback
 * URL is composed by the publisher in their dashboard from macros, so this
 * endpoint defines the contract and `docs/DEPLOYMENT.md` documents the exact
 * URL to paste. Authentication is a shared `secret` query param compared in
 * constant time against `CPALEAD_POSTBACK_SECRET` — CPAlead has no
 * request-signing scheme, so that secret is the only thing standing between
 * this endpoint and anyone who guesses the URL. Keep it long and random.
 *
 * Expected params: secret, subid (the Firebase uid), trans_id (CPAlead's
 * {lead_id} — required for idempotency), payout (USD), offer_id, offer_name.
 *
 * NOTE: CPAlead has no `status`/reversal macro (their dashboard rejects
 * unsupported macros outright), so unlike CPX they never report a chargeback
 * back to us — a fraudulent completion stays credited unless an admin claws it
 * back by hand. `status` is still read here so a manual replay or a future
 * CPAlead macro can mark one reversed, but nothing sends it today.
 */
export const cpaleadPostback = onRequest(
    {region: "us-central1", cors: false},
    async (req, res) => {
      try {
        const q = {...req.query, ...req.body} as Record<string, string>;
        const expected = process.env.CPALEAD_POSTBACK_SECRET ?? "";
        if (!expected) {
          console.error("cpaleadPostback: CPALEAD_POSTBACK_SECRET is not set");
          res.status(503).send("not configured");
          return;
        }
        if (!secretsMatch(String(q.secret ?? ""), expected)) {
          res.status(403).send("bad secret");
          return;
        }

        const uid = String(q.subid ?? "");
        const transId = String(q.trans_id ?? "");
        if (!uid || !transId) {
          res.status(400).send("missing params");
          return;
        }

        const offerId = String(q.offer_id ?? "");
        const rawName = String(q.offer_name ?? "").trim();
        const offerName = rawName ||
        (offerId ? `CPAlead Offer #${offerId}` : "CPAlead Offer");
        const status = String(q.status ?? "").toLowerCase();

        const outcome = await recordOfferCompletion({
          docId: `cpalead_${transId}`,
          uid,
          transId,
          offerName,
          payoutUsd: parseFloat(String(q.payout ?? "0")) || 0,
          isReversal: status === "2" || status === "reversed" ||
          status === "chargeback",
        });
        res.status(outcome.status).send(outcome.body);
      } catch (e) {
        console.error("cpaleadPostback error", e);
        res.status(500).send("error");
      }
    },
);

/**
 * Server-to-server postback Lootwalls calls when an offer is completed or
 * reversed.
 *
 * Lootwalls' docs define the URL as a fixed macro template —
 * `?user_id={user_id}&payout={payout}&status={status}&txn_id={transaction_id}`
 * — with no signing/auth macro of their own. Their dashboard separately issues
 * a "Secret (for postback)" value with no other documented use, so — following
 * the same pattern as CPAlead — that secret is appended as our own static
 * `secret` query param on the URL we register with them.
 *
 * Verified against live traffic: their `payout` is the RAW offer value,
 * unaffected by the dashboard's "Publisher Commission %" setting (that setting
 * only changes their own on-page display), so our own
 * `offerwallUserSharePercent` is the single place the split happens — no
 * double-discount.
 *
 * Their docs say `status` is numeric (1|0), but a live test postback sent the
 * word "approved", so word variants are matched too rather than only "0".
 */
export const lootwallsPostback = onRequest(
    {region: "us-central1", cors: false},
    async (req, res) => {
      try {
        const q = {...req.query, ...req.body} as Record<string, string>;
        // Never log `secret`.
        console.log("lootwallsPostback received", {
          user_id: q.user_id, payout: q.payout, status: q.status,
          txn_id: q.txn_id,
        });
        const expected = process.env.LOOTWALLS_POSTBACK_SECRET ?? "";
        if (!expected) {
          console.error("lootwallsPostback: LOOTWALLS_POSTBACK_SECRET is not set");
          res.status(503).send("not configured");
          return;
        }
        if (!secretsMatch(String(q.secret ?? ""), expected)) {
          res.status(403).send("bad secret");
          return;
        }

        const uid = String(q.user_id ?? "");
        const transId = String(q.txn_id ?? "");
        if (!uid || !transId) {
          res.status(400).send("missing params");
          return;
        }

        const statusVal = String(q.status ?? "1").toLowerCase();
        const outcome = await recordOfferCompletion({
          docId: `lootwalls_${transId}`,
          uid,
          transId,
          offerName: "Lootwalls Offer",
          payoutUsd: parseFloat(String(q.payout ?? "0")) || 0,
          isReversal: ["0", "reversed", "declined", "rejected", "cancelled",
            "canceled"].includes(statusVal),
        });
        res.status(outcome.status).send(outcome.body);
      } catch (e) {
        console.error("lootwallsPostback error", e);
        res.status(500).send("error");
      }
    },
);

/**
 * AdMob Server-Side Verification callback. AdMob calls this GET endpoint with a
 * signed reward; we record a verified impression keyed by the `custom_data`
 * nonce so `confirmRewardedAd` can (optionally, in STRICT_SSV mode) require it.
 *
 * The `signature`/`key_id` are verified against Google's published SSV public
 * keys (see `verifyAdmobSignature`) before the impression is trusted. An
 * unsigned/forged callback is still recorded — so a bad signature is visible
 * in `ad_impressions` for debugging — but with `verified: false`, which
 * `confirmRewardedAd`'s STRICT_SSV check rejects.
 *
 * Must answer 2xx to a bare, param-less ping too: the AdMob console's
 * "Test URL"/save-time reachability check hits this exact endpoint with no
 * real reward params attached, purely to confirm something is listening —
 * a 4xx there blocks saving the callback URL at all.
 */
export const admobSsv = onRequest(
    {region: "us-central1", cors: false},
    async (req, res) => {
      try {
        const q = req.query as Record<string, string>;
        const nonce = String(q.custom_data ?? "");
        const userId = String(q.user_id ?? "");
        if (!nonce) {
          res.status(200).send("ok — no custom_data, nothing to record");
          return;
        }

        const rawQuery = String(req.url.split("?")[1] ?? "");
        const verified = await verifyAdmobSignature(rawQuery);
        if (!verified) {
          await flagFraud(userId || "unknown", "admob_ssv_bad_signature", {nonce});
        }

        await cols.adImpressions.doc(nonce).set({
          uid: userId,
          adUnit: String(q.ad_unit ?? ""),
          rewardAmount: parseInt(String(q.reward_amount ?? "0"), 10),
          rewardItem: String(q.reward_item ?? ""),
          transactionId: String(q.transaction_id ?? ""),
          verified,
          createdAt: Timestamp.now(),
        });
        res.status(200).send("ok");
      } catch (e) {
        console.error("admobSsv error", e);
        res.status(500).send("error");
      }
    },
);
