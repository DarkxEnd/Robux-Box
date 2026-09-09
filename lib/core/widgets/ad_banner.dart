import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/providers.dart';
import '../utils/logger.dart';

/// An adaptive banner ad.
///
/// ## Policy note
///
/// Banners were removed from this app after an AdMob "Site behavior:
/// Navigation" policy strike caused by ads sitting too close to interactive
/// controls. This widget stays because the mechanics are correct and the ad
/// unit still exists, but it reserves its height *before* the ad loads and
/// keeps a hard gap from surrounding controls — placing one flush against a
/// button or a nav bar is what triggered the strike, and is what the policy
/// calls a deceptive placement. Do not shrink [_verticalGap].
class AdBanner extends ConsumerStatefulWidget {
  const AdBanner({super.key});

  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  static const double _verticalGap = 12;

  BannerAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad == null) _load();
  }

  Future<void> _load() async {
    final config = ref.read(appConfigProvider);
    final width = MediaQuery.sizeOf(context).width.truncate();

    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (size == null || !mounted) return;

    final ad = BannerAd(
      adUnitId: config.admobBannerAndroid,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          log.w('banner failed: ${err.code} ${err.message}');
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _verticalGap),
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
