/// Country → monetisation tier.
///
/// A *fallback only*. The authoritative map lives in Firestore at
/// `geo_tiers/overrides` and is applied by the server, so tiers can be
/// re-balanced without shipping an app update. This copy exists so the UI can
/// show a plausible tier badge before `resolveTier` returns, and so a first
/// launch with no network still renders something.
///
/// Tiers follow advertiser demand: T1 is the high-eCPM English-speaking and
/// Western European markets, T4 the lowest-CPM markets.
abstract final class TierMap {
  const TierMap._();

  static const Map<String, int> _tiers = {
    // T1
    'US': 1, 'CA': 1, 'GB': 1, 'AU': 1, 'NZ': 1, 'IE': 1,
    'DE': 1, 'NL': 1, 'SE': 1, 'NO': 1, 'DK': 1, 'FI': 1,
    'CH': 1, 'AT': 1, 'BE': 1, 'LU': 1, 'SG': 1, 'JP': 1,

    // T2
    'FR': 2, 'IT': 2, 'ES': 2, 'PT': 2, 'KR': 2, 'IL': 2,
    'AE': 2, 'SA': 2, 'QA': 2, 'KW': 2, 'PL': 2, 'CZ': 2,
    'GR': 2, 'HK': 2, 'TW': 2, 'CL': 2, 'HU': 2, 'SK': 2,

    // T3
    'BR': 3, 'MX': 3, 'AR': 3, 'CO': 3, 'PE': 3, 'TR': 3,
    'RU': 3, 'UA': 3, 'RO': 3, 'BG': 3, 'RS': 3, 'HR': 3,
    'MY': 3, 'TH': 3, 'ZA': 3, 'CN': 3, 'EC': 3, 'UY': 3,

    // T4
    'IN': 4, 'ID': 4, 'PH': 4, 'VN': 4, 'PK': 4, 'BD': 4,
    'NG': 4, 'KE': 4, 'GH': 4, 'EG': 4, 'MA': 4, 'DZ': 4,
    'TN': 4, 'IQ': 4, 'JO': 4, 'LB': 4, 'LK': 4, 'NP': 4,
    'MM': 4, 'KH': 4, 'ET': 4, 'TZ': 4, 'UG': 4, 'SD': 4,
  };

  /// Unlisted countries fall to T4 — the conservative choice. Guessing high
  /// would overpay in a market where the ad revenue does not cover it.
  static int tierFor(String? countryCode) {
    if (countryCode == null || countryCode.length != 2) return 4;
    return _tiers[countryCode.toUpperCase()] ?? 4;
  }

  static const Map<int, double> multipliers = {
    1: 1.00,
    2: 0.70,
    3: 0.45,
    4: 0.28,
  };

  static double multiplierFor(int tier) => multipliers[tier] ?? 0.28;
}
