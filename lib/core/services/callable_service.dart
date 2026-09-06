import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../error/failure.dart';
import '../error/result.dart';
import '../network/firebase_error_mapper.dart';
import '../utils/logger.dart';

/// The single door between the app and the server.
///
/// Every callable goes through here so three things are impossible to forget:
/// a timeout, a `Failure` instead of a raw exception, and a log line that
/// never contains the payload (payloads carry nonces and, for redemptions,
/// email addresses).
class CallableService {
  const CallableService(this._functions);

  final FirebaseFunctions _functions;

  /// Long enough to survive a cold start on a v2 function, short enough that a
  /// stuck request doesn't leave a spinner on screen forever.
  static const Duration _timeout = Duration(seconds: 30);

  Future<Result<Map<String, dynamic>>> call(
    String name, [
    Map<String, dynamic>? data,
  ]) async {
    try {
      final callable = _functions.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: _timeout),
      );
      final res = await callable.call<dynamic>(data).timeout(_timeout);
      return Result.success(_asMap(res.data));
    } on Object catch (e, s) {
      log.w('callable "$name" failed');
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  /// Convenience for callables whose result is a single field.
  Future<Result<T>> callField<T>(
    String name,
    String field, {
    Map<String, dynamic>? data,
    required T Function(Object? raw) parse,
  }) async {
    final res = await call(name, data);
    return res.map((map) => parse(map[field]));
  }

  /// The platform channel hands back `Map<Object?, Object?>`, which is not
  /// assignable to `Map<String, dynamic>`. Casting directly throws at runtime;
  /// rebuilding the map does not.
  static Map<String, dynamic> _asMap(Object? raw) => switch (raw) {
        final Map<Object?, Object?> m =>
          m.map((k, v) => MapEntry(k.toString(), _deep(v))),
        _ => <String, dynamic>{},
      };

  static Object? _deep(Object? v) => switch (v) {
        final Map<Object?, Object?> m =>
          m.map((k, val) => MapEntry(k.toString(), _deep(val))),
        final List<Object?> l => l.map(_deep).toList(),
        _ => v,
      };
}

/// Raised by services that need a `Failure` where no call was even attempted.
Failure offlineFailure() =>
    const NetworkFailure('No internet connection.', code: 'offline');
