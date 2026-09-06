import 'package:firebase_app_check/firebase_app_check.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';
import 'secure_storage_service.dart';

/// App Check attestation and the device context sent with earn requests.
///
/// ## The trap this class exists to document
///
/// When App Check rejects a request, Cloud Functions returns
/// `unauthenticated` — the *same* code as a genuinely signed-out caller. The
/// error mapper renders both as "please sign in", which has twice sent this
/// project hunting a phantom auth bug while the real cause was Play Integrity
/// failing (an unsigned build, a sideloaded APK, or a device that failed
/// attestation). If users report being asked to sign in while already signed
/// in, check App Check enforcement before touching the auth code.
class SecurityService {
  SecurityService(this._config, this._storage);

  final AppConfig _config;
  final SecureStorageService _storage;

  /// Activates attestation.
  ///
  /// Never throws: App Check failing to start must not stop the app from
  /// launching. `ENFORCE_APP_CHECK` defaults to off server-side for the same
  /// reason — a misconfigured secret should degrade security, not availability.
  Future<void> initialise() async {
    try {
      await FirebaseAppCheck.instance.activate(
        // Play Integrity in release; the debug provider otherwise, since a
        // debug build cannot pass integrity checks and would be locked out of
        // its own backend.
        androidProvider: _config.hasRealAdUnits
            ? AndroidProvider.playIntegrity
            : AndroidProvider.debug,
        appleProvider: _config.isProd
            ? AppleProvider.appAttest
            : AppleProvider.debug,
      );
      log.i('App Check activated');
    } catch (e, s) {
      log.e('App Check activation failed', e, s);
    }
  }

  /// The `device` block for `beginRewardedAd` and friends.
  Future<Map<String, dynamic>> deviceContext() => _storage.context();

  Future<String> deviceId() => _storage.deviceId();
}
