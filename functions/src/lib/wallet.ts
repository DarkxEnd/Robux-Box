import {HttpsError} from "firebase-functions/v2/https";
import {db, walletDoc, userDoc, subcols, Timestamp, FieldValue} from "./admin";
import {levelForXp} from "./economy";

export type TxType =
  | "rewarded_ad"
  | "offerwall"
  | "daily_reward"
  | "daily_game"
  | "promocode"
  | "referral"
  | "achievement"
  | "vip_bonus"
  | "vip_purchase"
  | "redemption"
  | "refund"
  | "admin_adjust"
  | "rate_app";

export interface CreditArgs {
  uid: string;
  amount: number;
  type: TxType;
  title: string;
  referenceId?: string;
  xp?: number;
  metadata?: Record<string, unknown>;
}

/**
 * Credits coins and writes the matching ledger entry in ONE transaction, so a
 * balance can never drift from its transaction history. This is the only way
 * coins are ever created — clients cannot write `wallets` or `transactions`
 * (see firestore.rules).
 */
export async function creditWallet(args: CreditArgs): Promise<number> {
  const {uid, amount, type, title, referenceId, xp = 0, metadata = {}} = args;
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "Credit amount must be positive.");
  }

  return db.runTransaction(async (t) => {
    const wRef = walletDoc(uid);
    const uRef = userDoc(uid);
    const [wSnap, uSnap] = await Promise.all([t.get(wRef), t.get(uRef)]);

    const balance = (wSnap.data()?.coins as number) ?? 0;
    const lifetime = (wSnap.data()?.lifetimeEarned as number) ?? 0;
    const newBalance = balance + amount;

    t.set(
        wRef,
        {
          uid,
          coins: newBalance,
          lifetimeEarned: lifetime + amount,
          updatedAt: Timestamp.now(),
        },
        {merge: true},
    );

    if (xp > 0) {
      const currentXp = (uSnap.data()?.xp as number) ?? 0;
      const newXp = currentXp + xp;
      t.set(
          uRef,
          {xp: newXp, level: levelForXp(newXp), updatedAt: Timestamp.now()},
          {merge: true},
      );
    }

    const txRef = subcols.transactions(uid).doc();
    t.set(txRef, {
      uid,
      direction: "credit",
      amount,
      type,
      title,
      referenceId: referenceId ?? null,
      balanceAfter: newBalance,
      metadata,
      createdAt: Timestamp.now(),
    });

    return newBalance;
  });
}

export interface DebitArgs {
  uid: string;
  amount: number;
  type: TxType;
  title: string;
  referenceId?: string;
  metadata?: Record<string, unknown>;
}

/**
 * Debits coins, refusing to go negative. Used for redemptions (a hold) and
 * coin-priced VIP purchases.
 */
export async function debitWallet(args: DebitArgs): Promise<number> {
  const {uid, amount, type, title, referenceId, metadata = {}} = args;
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "Debit amount must be positive.");
  }

  return db.runTransaction(async (t) => {
    const wRef = walletDoc(uid);
    const wSnap = await t.get(wRef);
    const balance = (wSnap.data()?.coins as number) ?? 0;
    if (balance < amount) {
      throw new HttpsError("failed-precondition", "Not enough coins.");
    }
    const newBalance = balance - amount;
    const spent = (wSnap.data()?.lifetimeSpent as number) ?? 0;

    t.set(
        wRef,
        {
          uid,
          coins: newBalance,
          lifetimeSpent: spent + amount,
          updatedAt: Timestamp.now(),
        },
        {merge: true},
    );

    const txRef = subcols.transactions(uid).doc();
    t.set(txRef, {
      uid,
      direction: "debit",
      amount,
      type,
      title,
      referenceId: referenceId ?? null,
      balanceAfter: newBalance,
      metadata,
      createdAt: Timestamp.now(),
    });

    return newBalance;
  });
}

/** Current coin balance (0 when the wallet has not been created yet). */
export async function coinBalance(uid: string): Promise<number> {
  const snap = await walletDoc(uid).get();
  return (snap.data()?.coins as number) ?? 0;
}

/** Bumps a per-UTC-day counter on the user doc (ads watched, games played…). */
export async function incrementDailyCounter(
    uid: string,
    field: string,
): Promise<void> {
  await userDoc(uid).set(
      {[field]: FieldValue.increment(1), updatedAt: Timestamp.now()},
      {merge: true},
  );
}
