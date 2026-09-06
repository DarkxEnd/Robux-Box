import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';
import '../error/failure.dart';
import '../error/result.dart';
import '../utils/logger.dart';

/// Which rewarded format to show. Both share one daily cap and cooldown
/// server-side; they differ only in payout (see `ECONOMY` on the server).
enum AdFormat {
  rewarded('rewarded'),
  interstitial('interstitial');

  const AdFormat(this.wire);

  final String wire;
}

/// Loads and shows rewarded ads.
///
/// Deliberately knows nothing about coins. The reward is decided by
/// `confirmRewardedAd` on the server after AdMob's signed SSV callback lands —
/// this class only reports *that the ad finished*, never *what it was worth*.
/// Keeping the payout out of the client is the whole anti-fraud design.
class AdsService {
  AdsService(this._config);

  final AppConfig _config;

  RewardedAd? _rewarded;
  RewardedInterstitialAd? _rewardedInterstitial;
  bool _initialised = false;

  /// Guards against two loads racing after a failed show.
  bool _loading = false;

  Future<void> initialise() async {
    if (_initialised) return;
    _initialised = true;
    try {
      await MobileAds.instance.initialize();
      // Nothing in this app is directed at children, but ads must still be
      // rated for a general audience: the app is on the Play Store under a
      // teen rating and MA content would violate it.
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
      );
      log.i('AdMob initialised');
    } catch (e, s) {
      log.e('AdMob init failed', e, s);
    }
  }

  bool get isRewardedReady => _rewarded != null;
  bool get isInterstitialReady => _rewardedInterstitial != null;

  bool isReady(AdFormat format) => switch (format) {
        AdFormat.rewarded => isRewardedReady,
        AdFormat.interstitial => isInterstitialReady,
      };

  /// Preloads so the user never waits on a tap. Safe to call repeatedly.
  Future<void> preload(AdFormat format) async {
    if (_loading || isReady(format)) return;
    _loading = true;
    try {
      switch (format) {
        case AdFormat.rewarded:
          await _loadRewarded();
        case AdFormat.interstitial:
          await _loadRewardedInterstitial();
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> _loadRewarded() {
    final completer = Completer<void>();
    RewardedAd.load(
      adUnitId: _config.admobRewardedAndroid,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (err) {
          log.w('rewarded load failed: ${err.code} ${err.message}');
          _rewarded = null;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    return completer.future;
  }

  Future<void> _loadRewardedInterstitial() {
    final completer = Completer<void>();
    RewardedInterstitialAd.load(
      adUnitId: _config.admobRewardedInterstitialAndroid,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitial = ad;
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (err) {
          log.w('rewarded interstitial load failed: ${err.code} ${err.message}');
          _rewardedInterstitial = null;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    return completer.future;
  }

  /// Shows an ad and resolves once it closes.
  ///
  /// [nonce] comes from `beginRewardedAd` and is handed to AdMob as SSV
  /// `custom_data`, which is what lets the server tie its signed callback back
  /// to this exact request. [uid] is sent as the SSV `user_id`.
  ///
  /// Returns success only when the user actually earned the reward — dismissing
  /// early resolves as an [OperationFailure], not silently as a success.
  Future<Result<void>> show({
    required AdFormat format,
    required String nonce,
    required String uid,
  }) async {
    if (!isReady(format)) {
      await preload(format);
      if (!isReady(format)) {
        return const Result.failure(
          OperationFailure(
            'No ad available right now. Please try again in a moment.',
            code: 'no-fill',
          ),
        );
      }
    }

    final completer = Completer<Result<void>>();
    var earned = false;

    void finish(Result<void> result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    // Generic because each ad class declares its own
    // FullScreenContentCallback<T>; one shared instance would not type-check.
    FullScreenContentCallback<T> callbacks<T extends AdWithoutView>() =>
        FullScreenContentCallback<T>(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _clear(format);
            // Preload the next one while the user is still on the screen.
            unawaited(preload(format));
            finish(
              earned
                  ? const Result.success(null)
                  : const Result.failure(
                      OperationFailure(
                        'You need to watch the whole ad to earn coins.',
                        code: 'ad-dismissed',
                      ),
                    ),
            );
          },
          onAdFailedToShowFullScreenContent: (ad, err) {
            log.w('ad failed to show: ${err.code} ${err.message}');
            ad.dispose();
            _clear(format);
            unawaited(preload(format));
            finish(
              const Result.failure(
                OperationFailure(
                  'That ad could not be shown. Please try again.',
                  code: 'ad-show-failed',
                ),
              ),
            );
          },
        );

    final ssv = ServerSideVerificationOptions(userId: uid, customData: nonce);

    try {
      switch (format) {
        case AdFormat.rewarded:
          final ad = _rewarded!
            ..fullScreenContentCallback = callbacks<RewardedAd>();
          await ad.setServerSideOptions(ssv);
          await ad.show(onUserEarnedReward: (_, __) => earned = true);
        case AdFormat.interstitial:
          final ad = _rewardedInterstitial!
            ..fullScreenContentCallback = callbacks<RewardedInterstitialAd>();
          await ad.setServerSideOptions(ssv);
          await ad.show(onUserEarnedReward: (_, __) => earned = true);
      }
    } catch (e, s) {
      log.e('ad show threw', e, s);
      _clear(format);
      finish(const Result.failure(UnexpectedFailure()));
    }

    // A hung ad SDK must not leave the caller waiting forever.
    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => const Result.failure(
        OperationFailure('The ad timed out.', code: 'ad-timeout'),
      ),
    );
  }

  void _clear(AdFormat format) {
    switch (format) {
      case AdFormat.rewarded:
        _rewarded = null;
      case AdFormat.interstitial:
        _rewardedInterstitial = null;
    }
  }

  void dispose() {
    _rewarded?.dispose();
    _rewardedInterstitial?.dispose();
    _rewarded = null;
    _rewardedInterstitial = null;
  }
}
