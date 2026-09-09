import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Minimal logger. Debug builds print; release builds forward warnings and
/// errors to the platform log only — never to stdout, and never with user data.
final log = _Logger();

class _Logger {
  void d(String message) {
    if (kDebugMode) developer.log(message, name: 'robux_box');
  }

  void i(String message) {
    developer.log(message, name: 'robux_box', level: 800);
  }

  void w(String message, [Object? error, StackTrace? stack]) {
    developer.log(
      message,
      name: 'robux_box',
      level: 900,
      error: error,
      stackTrace: stack,
    );
  }

  void e(String message, [Object? error, StackTrace? stack]) {
    developer.log(
      message,
      name: 'robux_box',
      level: 1000,
      error: error,
      stackTrace: stack,
    );
  }
}
