import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/preferences_service.dart';

/// Light/dark/system, persisted locally.
class ThemeController extends Notifier<ThemeMode> {
  ThemeController(this._prefs);

  final PreferencesService _prefs;

  @override
  ThemeMode build() => _parse(_prefs.themeMode);

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _prefs.setThemeMode(mode.name);
  }

  /// Cycles system → light → dark → system, for the single-tap toggle in
  /// settings.
  Future<void> cycle() => set(switch (state) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      });

  static ThemeMode _parse(String v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
