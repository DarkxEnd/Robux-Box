import {cols} from "./admin";

/**
 * Default country → monetisation tier map. T1 pays the most (high-eCPM
 * markets), T4 the least. Anything unlisted falls to T4, which is the
 * conservative choice: paying too little is recoverable, paying too much is
 * not. Overridable at runtime via `geo_tiers/overrides` so a tier can be
 * corrected without a redeploy.
 */
const DEFAULT_TIERS: Record<string, number> = {
  // T1
  US: 1, CA: 1, GB: 1, AU: 1, NZ: 1, IE: 1, DE: 1, CH: 1, NO: 1, DK: 1,
  SE: 1, NL: 1, AT: 1, BE: 1, FI: 1, LU: 1, SG: 1, JP: 1, KR: 1,
  // T2
  FR: 2, IT: 2, ES: 2, PT: 2, PL: 2, CZ: 2, GR: 2, IL: 2, AE: 2, SA: 2,
  QA: 2, KW: 2, BH: 2, TW: 2, HK: 2, MY: 2, CL: 2, EE: 2, LT: 2, LV: 2,
  // T3
  BR: 3, MX: 3, AR: 3, CO: 3, TR: 3, RO: 3, BG: 3, HU: 3, HR: 3, RS: 3,
  ZA: 3, TH: 3, RU: 3, UA: 3, KZ: 3, PE: 3, CR: 3, PA: 3, UY: 3,
  // T4
  IN: 4, ID: 4, PH: 4, VN: 4, PK: 4, BD: 4, NG: 4, KE: 4, EG: 4, MA: 4,
  DZ: 4, TN: 4, IQ: 4, JO: 4, LB: 4, YE: 4, SD: 4, LY: 4, SY: 4, NP: 4,
  LK: 4, MM: 4, KH: 4, BO: 4, PY: 4, EC: 4, VE: 4, GT: 4, HN: 4, SV: 4,
};

let cachedOverrides: Record<string, number> | null = null;
let cachedAt = 0;
const CACHE_TTL_MS = 5 * 60 * 1000;

async function overrides(): Promise<Record<string, number>> {
  if (cachedOverrides && Date.now() - cachedAt < CACHE_TTL_MS) {
    return cachedOverrides;
  }
  try {
    const snap = await cols.geoTiers.doc("overrides").get();
    cachedOverrides = (snap.data()?.map as Record<string, number>) ?? {};
  } catch {
    // A config read failure must never break earning — fall back to defaults.
    cachedOverrides = {};
  }
  cachedAt = Date.now();
  return cachedOverrides;
}

/**
 * The authoritative tier for a country code. Always resolved server-side: the
 * client's GPS-derived guess is a UI hint only, so a spoofed location changes
 * what the UI previews but never the actual payout.
 */
export async function tierForCountry(countryCode: string): Promise<number> {
  const cc = (countryCode || "").toUpperCase().slice(0, 2);
  const map = await overrides();
  const tier = map[cc] ?? DEFAULT_TIERS[cc] ?? 4;
  return tier >= 1 && tier <= 4 ? tier : 4;
}
