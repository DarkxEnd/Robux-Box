import * as crypto from "crypto";
import * as https from "https";

/**
 * AdMob Server-Side Verification signature checking.
 *
 * AdMob signs each SSV callback with one of the ECDSA keys published at the URL
 * below. The signed payload is the raw query string with the `signature` and
 * `key_id` parameters (and everything after them) removed — order matters, so
 * the raw string is used rather than a re-serialised parse.
 *
 * Without this check, `admobSsv` would accept any forged callback and
 * `STRICT_SSV` mode would be worthless: anyone who guessed the URL could mint
 * "verified" impressions. That was a real, exploited gap in this project.
 */
const KEY_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";
const CACHE_TTL_MS = 24 * 60 * 60 * 1000;

interface AdmobKey {
  keyId: number;
  pem: string;
  base64: string;
}

let cachedKeys: Map<string, string> | null = null;
let cachedAt = 0;

function fetchJson(url: string): Promise<string> {
  return new Promise((resolve, reject) => {
    https
        .get(url, (res) => {
          if (res.statusCode !== 200) {
            reject(new Error(`key fetch failed: HTTP ${res.statusCode}`));
            res.resume();
            return;
          }
          let raw = "";
          res.setEncoding("utf8");
          res.on("data", (c) => (raw += c));
          res.on("end", () => resolve(raw));
        })
        .on("error", reject);
  });
}

async function publicKeys(): Promise<Map<string, string>> {
  if (cachedKeys && Date.now() - cachedAt < CACHE_TTL_MS) return cachedKeys;
  const raw = await fetchJson(KEY_URL);
  const parsed = JSON.parse(raw) as {keys: AdmobKey[]};
  const map = new Map<string, string>();
  for (const k of parsed.keys ?? []) {
    if (k.keyId !== undefined && k.pem) map.set(String(k.keyId), k.pem);
  }
  cachedKeys = map;
  cachedAt = Date.now();
  return map;
}

/**
 * Verifies an AdMob SSV callback from its RAW query string (everything after
 * `?`, exactly as received — do not re-encode it).
 *
 * Returns false rather than throwing: an unverifiable callback is still worth
 * recording (with `verified: false`) so fraud attempts stay visible.
 */
export async function verifyAdmobSignature(rawQuery: string): Promise<boolean> {
  try {
    if (!rawQuery) return false;

    const sigIndex = rawQuery.indexOf("&signature=");
    if (sigIndex === -1) return false;

    // Signed content is everything BEFORE `&signature=`.
    const signedData = rawQuery.substring(0, sigIndex);

    const params = new URLSearchParams(rawQuery);
    const signature = params.get("signature");
    const keyId = params.get("key_id");
    if (!signature || !keyId) return false;

    const keys = await publicKeys();
    const pem = keys.get(keyId);
    if (!pem) {
      console.warn(`admobVerify: unknown key_id ${keyId}`);
      return false;
    }

    // AdMob sends the signature base64url-encoded.
    const sigBuf = Buffer.from(signature, "base64url");

    // Google documents the signature as DER, but has been observed emitting
    // the raw IEEE-P1363 (r||s) form too. Try both before rejecting.
    for (const format of ["der", "ieee-p1363"] as const) {
      try {
        const ok = crypto.verify(
            "sha256",
            Buffer.from(signedData, "utf8"),
            {key: pem, dsaEncoding: format},
            sigBuf,
        );
        if (ok) return true;
      } catch {
        // Wrong encoding for this attempt — fall through and try the other.
      }
    }
    return false;
  } catch (e) {
    console.error("verifyAdmobSignature error", e);
    return false;
  }
}
