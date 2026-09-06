import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/providers.dart';
import 'core/l10n/gen/app_localizations.dart';
import 'core/l10n/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// The root widget.
class RobuxBoxApp extends ConsumerWidget {
  const RobuxBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Robux Box',
      debugShowCheckedModeBanner: false,
      routerConfig: router,

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      // Null locale means "follow the device", which MaterialApp resolves
      // against supportedLocales.
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      builder: (context, child) {
        // Clamp text scaling. Users routinely run 200% system text, and the
        // balance card and nav bar overflow well before that — clamping is
        // better than letting the layout break, and 1.3 still satisfies the
        // accessibility floor.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
