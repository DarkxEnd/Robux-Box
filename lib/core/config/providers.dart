import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/locale_controller.dart';
import '../services/ads_service.dart';
import '../services/callable_service.dart';
import '../services/connectivity_service.dart';
import '../services/geo_tier_service.dart';
import '../services/notification_service.dart';
import '../services/offerwall_service.dart';
import '../services/preferences_service.dart';
import '../services/secure_storage_service.dart';
import '../services/security_service.dart';
import '../services/sound_service.dart';
import '../theme/theme_controller.dart';
import 'app_config.dart';

/// Build-time configuration.
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

/// Set once in `bootstrap()`, before `runApp`. Overridden there rather than
/// created lazily because SharedPreferences is async and the theme has to be
/// known on the very first frame — otherwise the app flashes the wrong theme.
final preferencesProvider = Provider<PreferencesService>((ref) {
  throw StateError('preferencesProvider must be overridden in bootstrap()');
});

// ---------------------------------------------------------------------------
// Firebase SDK singletons — injected rather than reached for globally, so
// tests can substitute fakes.
// ---------------------------------------------------------------------------

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final functionsProvider = Provider<FirebaseFunctions>((ref) {
  // Every callable is deployed to us-central1; using the default region here
  // silently 404s instead.
  return FirebaseFunctions.instanceFor(region: 'us-central1');
});

final storageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final messagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

// ---------------------------------------------------------------------------
// Auth state
// ---------------------------------------------------------------------------

/// The current signed-in user, or null. Rebuilds on every auth change.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// The current uid, or null when signed out.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

/// Whether the signed-in user holds the admin custom claim.
///
/// Read from the ID token, not from a Firestore field: the claim is what
/// `firestore.rules` and every admin callable actually check, so trusting a
/// document here would show an admin UI that the server then refuses.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return false;
  try {
    final token = await user.getIdTokenResult();
    return token.claims?['admin'] == true;
  } catch (_) {
    return false;
  }
});

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

final callableServiceProvider = Provider<CallableService>((ref) {
  return CallableService(ref.watch(functionsProvider));
});

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService(
    ref.watch(appConfigProvider),
    ref.watch(secureStorageProvider),
  );
});

final adsServiceProvider = Provider<AdsService>((ref) {
  final service = AdsService(ref.watch(appConfigProvider));
  ref.onDispose(service.dispose);
  return service;
});

final offerwallServiceProvider = Provider<OfferwallService>((ref) {
  return OfferwallService(ref.watch(callableServiceProvider));
});

final geoTierServiceProvider = Provider<GeoTierService>((ref) {
  return const GeoTierService();
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final soundServiceProvider = Provider<SoundService>((ref) {
  return SoundService(ref.watch(preferencesProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    ref.watch(messagingProvider),
    FlutterLocalNotificationsPlugin(),
  );
});

/// Online/offline, for the banner at the top of the shell.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).onStatusChange;
});

// ---------------------------------------------------------------------------
// UI preferences
// ---------------------------------------------------------------------------

final themeModeProvider = NotifierProvider<ThemeController, ThemeMode>(() {
  throw StateError('themeModeProvider must be overridden in bootstrap()');
});

final localeProvider = NotifierProvider<LocaleController, Locale?>(() {
  throw StateError('localeProvider must be overridden in bootstrap()');
});
