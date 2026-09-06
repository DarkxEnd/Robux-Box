import 'package:flutter/foundation.dart';

/// Build-time configuration, supplied with `--dart-define`.
///
/// Example:
///   flutter build appbundle \
///     --dart-define=FLAVOR=prod \
///     --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-xxx/yyy
///
/// Ad unit ids default to Google's public TEST ids so a developer build always
/// serves something instead of crashing — a real build must override them.
enum Flavor { dev, staging, prod }

class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.useEmulators,
    required this.admobRewardedAndroid,
    required this.admobRewardedInterstitialAndroid,
    required this.admobAppOpenAndroid,
    required this.admobBannerAndroid,
    required this.minWithdrawCoins,
    required this.supportEmail,
    required this.privacyUrl,
    required this.termsUrl,
  });

  factory AppConfig.fromEnvironment() {
    const flavorName = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    final flavor = switch (flavorName) {
      'prod' => Flavor.prod,
      'staging' => Flavor.staging,
      _ => Flavor.dev,
    };

    return AppConfig(
      flavor: flavor,
      useEmulators: const bool.fromEnvironment(
        'USE_EMULATORS',
        defaultValue: false,
      ),
      admobRewardedAndroid: const String.fromEnvironment(
        'ADMOB_REWARDED_ANDROID',
        defaultValue: 'ca-app-pub-3940256099942544/5224354917',
      ),
      admobRewardedInterstitialAndroid: const String.fromEnvironment(
        'ADMOB_REWARDED_INTERSTITIAL_ANDROID',
        defaultValue: 'ca-app-pub-3940256099942544/5354046379',
      ),
      admobAppOpenAndroid: const String.fromEnvironment(
        'ADMOB_APP_OPEN_ANDROID',
        defaultValue: 'ca-app-pub-3940256099942544/9257395921',
      ),
      admobBannerAndroid: const String.fromEnvironment(
        'ADMOB_BANNER_ANDROID',
        defaultValue: 'ca-app-pub-3940256099942544/6300978111',
      ),
      minWithdrawCoins: const int.fromEnvironment(
        'MIN_WITHDRAW_COINS',
        defaultValue: 1000,
      ),
      supportEmail: const String.fromEnvironment(
        'SUPPORT_EMAIL',
        defaultValue: 'robuxbox10@gmail.com',
      ),
      privacyUrl: const String.fromEnvironment(
        'PRIVACY_URL',
        defaultValue: 'https://dark7end.github.io/Robux-Box/privacy.html',
      ),
      termsUrl: const String.fromEnvironment(
        'TERMS_URL',
        defaultValue: 'https://dark7end.github.io/Robux-Box/terms.html',
      ),
    );
  }

  final Flavor flavor;
  final bool useEmulators;
  final String admobRewardedAndroid;
  final String admobRewardedInterstitialAndroid;
  final String admobAppOpenAndroid;
  final String admobBannerAndroid;
  final int minWithdrawCoins;
  final String supportEmail;
  final String privacyUrl;
  final String termsUrl;

  bool get isProd => flavor == Flavor.prod;

  /// Whether real (non-test) ad unit ids are configured. Used to decide
  /// whether App Check should use a debug provider.
  bool get hasRealAdUnits =>
      !admobRewardedAndroid.startsWith('ca-app-pub-3940256099942544');

  @visibleForTesting
  AppConfig copyWith({Flavor? flavor, bool? useEmulators}) => AppConfig(
    flavor: flavor ?? this.flavor,
    useEmulators: useEmulators ?? this.useEmulators,
    admobRewardedAndroid: admobRewardedAndroid,
    admobRewardedInterstitialAndroid: admobRewardedInterstitialAndroid,
    admobAppOpenAndroid: admobAppOpenAndroid,
    admobBannerAndroid: admobBannerAndroid,
    minWithdrawCoins: minWithdrawCoins,
    supportEmail: supportEmail,
    privacyUrl: privacyUrl,
    termsUrl: termsUrl,
  );
}
