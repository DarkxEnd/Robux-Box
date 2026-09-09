import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/providers.dart';
import 'core/l10n/locale_controller.dart';
import 'core/services/notification_service.dart';
import 'core/services/preferences_service.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/logger.dart';
import 'firebase_options.dart';

/// Starts the app.
///
/// Order matters here:
///  1. Firebase, because everything else depends on it.
///  2. Crashlytics handlers, so a crash *during the rest of startup* is still
///     reported — installing them later loses exactly the crashes that are
///     hardest to reproduce.
///  3. App Check, before the first callable can run.
///  4. Preferences, because the theme must be known for the first frame.
///
/// The whole body runs inside `runZonedGuarded` so an async error with no
/// handler reaches Crashlytics rather than vanishing.
Future<void> bootstrap() async {
  // Deliberately not awaited: this is the app's root zone and runs for the
  // process lifetime.
  unawaited(
    runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();

        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
        );

        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        _installErrorHandlers();

        // Registered before runApp: a push that launches the app from cold start
        // is delivered to this handler before the first frame.
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        final prefs = await PreferencesService.create();
        final config = AppConfig.fromEnvironment();

        final container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            appConfigProvider.overrideWithValue(config),
            themeModeProvider.overrideWith(() => ThemeController(prefs)),
            localeProvider.overrideWith(() => LocaleController(prefs)),
          ],
        );

        // App Check must be active before the first callable, but the app does
        // not need to wait for it to paint — an early call simply retries.
        unawaited(container.read(securityServiceProvider).initialise());
        unawaited(container.read(adsServiceProvider).initialise());

        runApp(
          UncontrolledProviderScope(
            container: container,
            child: const RobuxBoxApp(),
          ),
        );
      },
      (error, stack) {
        log.e('uncaught zone error', error, stack);
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      },
    ),
  );
}

void _installErrorHandlers() {
  final crashlytics = FirebaseCrashlytics.instance;

  // Off in debug: local crashes belong in the console, and uploading them
  // pollutes the release crash-free-users metric.
  unawaited(crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode));

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    crashlytics.recordFlutterFatalError(details);
  };

  // Errors from the engine that never reach a Dart zone (platform channels,
  // the raster thread) arrive here instead.
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}
