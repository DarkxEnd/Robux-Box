import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/preferences_service.dart';

/// The eight locales the app ships in.
///
/// Chosen from where the users actually are: English and Spanish cover the
/// Americas, Arabic the MENA region (the single largest cohort), Hindi and
/// Indonesian the two biggest T4 markets, plus Portuguese, French and Turkish.
const supportedLocales = <Locale>[
  Locale('en'),
  Locale('ar'),
  Locale('es'),
  Locale('pt'),
  Locale('fr'),
  Locale('hi'),
  Locale('id'),
  Locale('tr'),
];

/// Human-readable names, each written in its own language — a user looking for
/// their language will not recognise its English name.
const localeNames = <String, String>{
  'en': 'English',
  'ar': 'العربية',
  'es': 'Español',
  'pt': 'Português',
  'fr': 'Français',
  'hi': 'हिन्दी',
  'id': 'Bahasa Indonesia',
  'tr': 'Türkçe',
};

/// Null state means "follow the device", which is the default.
class LocaleController extends Notifier<Locale?> {
  LocaleController(this._prefs);

  final PreferencesService _prefs;

  @override
  Locale? build() {
    final code = _prefs.locale;
    if (code == null) return null;
    return supportedLocales.where((l) => l.languageCode == code).firstOrNull;
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    await _prefs.setLocale(locale?.languageCode);
  }
}
