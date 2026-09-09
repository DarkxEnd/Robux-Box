import 'package:flutter/services.dart';

import 'preferences_service.dart';

/// Haptics and system sounds for reward moments.
///
/// Uses only the platform's own feedback rather than bundled audio: an app
/// that plays its own coin sound through the media channel interrupts whatever
/// the user is listening to, which is a common one-star complaint in this
/// category. Both channels honour the user's settings toggles.
class SoundService {
  const SoundService(this._prefs);

  final PreferencesService _prefs;

  /// A coin landing. The double tap reads as "something was added".
  Future<void> reward() async {
    if (!_prefs.hapticsEnabled) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  }

  /// A big win — spin jackpot, achievement unlocked.
  Future<void> celebrate() async {
    if (!_prefs.hapticsEnabled) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await HapticFeedback.heavyImpact();
  }

  Future<void> tap() async {
    if (!_prefs.hapticsEnabled) return;
    await HapticFeedback.selectionClick();
  }

  Future<void> error() async {
    if (!_prefs.hapticsEnabled) return;
    await HapticFeedback.vibrate();
  }

  Future<void> click() async {
    if (!_prefs.soundEnabled) return;
    await SystemSound.play(SystemSoundType.click);
  }
}
