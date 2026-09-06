import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

/// Non-sensitive local settings.
///
/// Everything here is a *preference*, never a fact the app trusts: a user can
/// edit shared_preferences on a rooted device, so nothing that affects coins,
/// VIP or eligibility may be stored here. Those all live server-side.
class PreferencesService {
  const PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static Future<PreferencesService> create() async =>
      PreferencesService(await SharedPreferences.getInstance());

  static const _themeMode = 'theme_mode';
  static const _locale = 'locale';
  static const _soundEnabled = 'sound_enabled';
  static const _hapticsEnabled = 'haptics_enabled';
  static const _onboardingDone = 'onboarding_done';
  static const _lastOfferwallProvider = 'last_offerwall_provider';
  static const _pushPromptShown = 'push_prompt_shown';

  String get themeMode => _prefs.getString(_themeMode) ?? 'system';
  Future<void> setThemeMode(String v) => _write(_themeMode, v);

  /// Null means "follow the device language".
  String? get locale => _prefs.getString(_locale);
  Future<void> setLocale(String? v) async {
    if (v == null) {
      await _remove(_locale);
    } else {
      await _write(_locale, v);
    }
  }

  bool get soundEnabled => _prefs.getBool(_soundEnabled) ?? true;
  Future<void> setSoundEnabled(bool v) => _writeBool(_soundEnabled, v);

  bool get hapticsEnabled => _prefs.getBool(_hapticsEnabled) ?? true;
  Future<void> setHapticsEnabled(bool v) => _writeBool(_hapticsEnabled, v);

  bool get onboardingDone => _prefs.getBool(_onboardingDone) ?? false;
  Future<void> setOnboardingDone(bool v) => _writeBool(_onboardingDone, v);

  String? get lastOfferwallProvider => _prefs.getString(_lastOfferwallProvider);
  Future<void> setLastOfferwallProvider(String v) =>
      _write(_lastOfferwallProvider, v);

  /// Whether the "turn on notifications" explainer has been shown. Android 13+
  /// only allows one permission prompt, so the app must not waste it.
  bool get pushPromptShown => _prefs.getBool(_pushPromptShown) ?? false;
  Future<void> setPushPromptShown(bool v) => _writeBool(_pushPromptShown, v);

  Future<void> _write(String k, String v) async {
    try {
      await _prefs.setString(k, v);
    } catch (e) {
      log.w('prefs write failed: $k', e);
    }
  }

  Future<void> _writeBool(String k, bool v) async {
    try {
      await _prefs.setBool(k, v);
    } catch (e) {
      log.w('prefs write failed: $k', e);
    }
  }

  Future<void> _remove(String k) async {
    try {
      await _prefs.remove(k);
    } catch (e) {
      log.w('prefs remove failed: $k', e);
    }
  }
}
