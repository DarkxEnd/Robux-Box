import {onCall, HttpsError} from "firebase-functions/v2/https";
import {userDoc, Timestamp} from "../lib/admin";
import {ECONOMY, isSameUtcDay, weightedPick} from "../lib/economy";
import {creditWallet} from "../lib/wallet";
import {
  CALLABLE_OPTS,
  assertAccountActive,
  rateLimit,
  requireAuth,
} from "../lib/security";

type GameKind = "spin" | "chest";

const TABLES: Record<GameKind, {prizes: readonly number[]; weights: readonly number[]; field: string; label: string}> = {
  spin: {
    prizes: ECONOMY.spinPrizes,
    weights: ECONOMY.spinWeights,
    field: "lastSpinAt",
    label: "Spin wheel",
  },
  chest: {
    prizes: ECONOMY.chestPrizes,
    weights: ECONOMY.chestWeights,
    field: "lastChestAt",
    label: "Lucky chest",
  },
};

/**
 * One free play per UTC day per game. The prize is drawn server-side and the
 * winning index is returned so the client wheel can animate to the segment the
 * backend actually awarded — the animation follows the result, never the
 * other way round.
 */
export const playDailyGame = onCall(CALLABLE_OPTS, async (req) => {
  const uid = requireAuth(req);
  await assertAccountActive(uid);
  await rateLimit(uid, "daily_game", 20, 3600);

  const kind = (String(req.data?.game ?? "spin") as GameKind);
  const table = TABLES[kind];
  if (!table) throw new HttpsError("invalid-argument", "Unknown game.");

  const snap = await userDoc(uid).get();
  const user = snap.data() ?? {};
  const last = (user[table.field] as FirebaseFirestore.Timestamp | undefined)?.toDate();
  if (last && isSameUtcDay(last, new Date())) {
    throw new HttpsError("failed-precondition", "Come back tomorrow for another play.");
  }

  const index = weightedPick(table.weights);
  const coins = table.prizes[index];

  await userDoc(uid).set(
      {[table.field]: Timestamp.now(), updatedAt: Timestamp.now()},
      {merge: true},
  );

  const balance = await creditWallet({
    uid,
    amount: coins,
    type: "daily_game",
    title: table.label,
    metadata: {game: kind, index},
  });

  return {coins, balance, index};
});
