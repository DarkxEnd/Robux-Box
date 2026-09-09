import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {cols, subcols, Timestamp} from "../lib/admin";
import {creditWallet} from "../lib/wallet";
import {sendUserNotification} from "../lib/notify";

/**
 * Recomputes achievement progress whenever a wallet changes, and pays the coin
 * reward the first time each one unlocks.
 *
 * Definitions live in the `achievements` collection so new ones can be added
 * without a redeploy. Each carries: title, description, metric
 * (lifetimeEarned | lifetimeSpent | coins), threshold, rewardCoins.
 */
export const syncAchievementsOnWalletWrite = onDocumentWritten(
    {document: "wallets/{uid}", region: "us-central1"},
    async (event) => {
      const after = event.data?.after.data();
      if (!after) return;
      const uid = event.params.uid as string;

      const defs = await cols.achievements.where("isActive", "==", true).get();
      if (defs.empty) return;

      for (const def of defs.docs) {
        const d = def.data();
        const metric = String(d.metric ?? "lifetimeEarned");
        const threshold = Number(d.threshold ?? 0);
        const value = Number(after[metric] ?? 0);
        if (threshold <= 0 || value < threshold) continue;

        const mineRef = subcols.achievements(uid).doc(def.id);
        const mine = await mineRef.get();
        if (mine.exists && mine.data()?.unlocked === true) continue;

        await mineRef.set(
            {
              achievementId: def.id,
              unlocked: true,
              value,
              unlockedAt: Timestamp.now(),
            },
            {merge: true},
        );

        const reward = Number(d.rewardCoins ?? 0);
        if (reward > 0) {
          await creditWallet({
            uid,
            amount: reward,
            type: "achievement",
            title: `Achievement: ${d.title ?? def.id}`,
            referenceId: def.id,
          });
        }

        await sendUserNotification(uid, {
          type: "reward",
          title: "Achievement unlocked 🏆",
          body: `${d.title ?? def.id}${reward > 0 ? ` — +${reward} coins` : ""}`,
          deeplink: "/achievements",
        });
      }
    },
);
