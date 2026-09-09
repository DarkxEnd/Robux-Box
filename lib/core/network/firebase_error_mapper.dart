import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../error/failure.dart';
import '../utils/logger.dart';

/// Turns any Firebase exception into a [Failure] with a message worth showing.
///
/// IMPORTANT GOTCHA: Cloud Functions returns `unauthenticated` both for a real
/// signed-out caller AND for a request rejected by App Check before the handler
/// runs. Mapping both to "please sign in" has twice sent this project chasing a
/// phantom auth bug while the real cause was Play Integrity attestation
/// failing. The message below deliberately hints at both.
abstract final class FirebaseErrorMapper {
  const FirebaseErrorMapper._();

  static Failure map(Object error, [StackTrace? stack]) {
    log.e('Firebase error', error, stack);

    if (error is FirebaseFunctionsException) return _functions(error);
    if (error is FirebaseAuthException) return _auth(error);
    if (error is FirebaseException) return _firestore(error);
    if (error is TimeoutException) {
      return const NetworkFailure(
        'That took too long. Check your connection and try again.',
        code: 'timeout',
      );
    }
    if (error is SocketException) {
      return const NetworkFailure('No internet connection.', code: 'offline');
    }
    return const UnexpectedFailure();
  }

  static Failure _functions(FirebaseFunctionsException e) {
    final message = (e.message ?? '').trim();
    return switch (e.code) {
      'unauthenticated' => AuthFailure(
        message.isNotEmpty
            ? message
            : 'Please sign in to continue. If you are already signed in, '
                  'update the app and try again.',
        code: e.code,
      ),
      'permission-denied' => PermissionFailure(
        _orDefault(message, 'You cannot do that.'),
        code: e.code,
      ),
      'resource-exhausted' ||
      'failed-precondition' ||
      'invalid-argument' ||
      'not-found' ||
      'deadline-exceeded' ||
      'already-exists' => OperationFailure(
        _orDefault(message, 'That request was rejected.'),
        code: e.code,
      ),
      'unavailable' => const NetworkFailure(
        'Service temporarily unavailable. Please try again.',
        code: 'unavailable',
      ),
      _ => const UnexpectedFailure(),
    };
  }

  static Failure _auth(FirebaseAuthException e) {
    final message = switch (e.code) {
      'invalid-email' => 'That email address is not valid.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Incorrect email or password.',
      'email-already-in-use' => 'That email is already registered.',
      'weak-password' => 'Choose a stronger password (at least 6 characters).',
      'requires-recent-login' => 'Please sign in again to continue.',
      'too-many-requests' => 'Too many attempts. Try again later.',
      'network-request-failed' => 'No internet connection.',
      'invalid-verification-code' => 'That code is not correct.',
      'session-expired' => 'That code expired. Request a new one.',
      _ => 'Sign-in failed. Please try again.',
    };
    if (e.code == 'network-request-failed') {
      return NetworkFailure(message, code: e.code);
    }
    return AuthFailure(message, code: e.code);
  }

  static Failure _firestore(FirebaseException e) => switch (e.code) {
    'permission-denied' => const PermissionFailure(
      'You do not have access to that.',
      code: 'permission-denied',
    ),
    'unavailable' => const NetworkFailure(
      'No internet connection.',
      code: 'unavailable',
    ),
    'not-found' => const OperationFailure('Not found.', code: 'not-found'),
    _ => const UnexpectedFailure(),
  };

  static String _orDefault(String value, String fallback) =>
      value.isEmpty ? fallback : value;
}
