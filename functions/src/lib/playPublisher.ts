import {google} from "googleapis";
import {HttpsError} from "firebase-functions/v2/https";

/**
 * Google Play Developer API verification for real-money VIP subscriptions.
 *
 * The credential is the base64 of a service-account JSON key
 * (`PLAY_SERVICE_ACCOUNT_JSON_BASE64`) — base64 because raw multi-line JSON
 * does not survive a `.env` round-trip and silently corrupts the whole file.
 * Without the secret this fails CLOSED: an unverified purchase is never
 * credited.
 */
const PACKAGE_NAME = "com.robuxbox.app";

function credentials(): {client_email: string; private_key: string} {
  const b64 = process.env.PLAY_SERVICE_ACCOUNT_JSON_BASE64 ?? "";
  if (!b64) {
    throw new HttpsError(
        "failed-precondition",
        "Purchase verification is not configured.",
    );
  }
  try {
    return JSON.parse(Buffer.from(b64, "base64").toString("utf8"));
  } catch {
    throw new HttpsError(
        "failed-precondition",
        "Purchase verification credential is malformed.",
    );
  }
}

export interface VerifiedSubscription {
  valid: boolean;
  expiryMillis: number;
  autoRenewing: boolean;
  orderId?: string;
}

/**
 * Verifies a subscription purchase token with Google Play and returns its real
 * expiry. Also acknowledges the purchase — Play automatically refunds any
 * purchase left unacknowledged for three days.
 */
export async function verifyPlaySubscription(
    productId: string,
    purchaseToken: string,
): Promise<VerifiedSubscription> {
  const creds = credentials();
  const jwt = new google.auth.JWT({
    email: creds.client_email,
    key: creds.private_key,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });

  const publisher = google.androidpublisher({version: "v3", auth: jwt});

  const res = await publisher.purchases.subscriptions.get({
    packageName: PACKAGE_NAME,
    subscriptionId: productId,
    token: purchaseToken,
  });

  const data = res.data;
  const expiryMillis = Number(data.expiryTimeMillis ?? 0);
  const valid = expiryMillis > Date.now();

  // 0 = yet to be acknowledged.
  if (valid && data.acknowledgementState === 0) {
    try {
      await publisher.purchases.subscriptions.acknowledge({
        packageName: PACKAGE_NAME,
        subscriptionId: productId,
        token: purchaseToken,
        requestBody: {developerPayload: ""},
      });
    } catch (e) {
      console.error("Play acknowledge failed", e);
    }
  }

  return {
    valid,
    expiryMillis,
    autoRenewing: Boolean(data.autoRenewing),
    orderId: data.orderId ?? undefined,
  };
}
