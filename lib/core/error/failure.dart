import 'package:equatable/equatable.dart';

/// A user-presentable failure. Every layer returns one of these instead of
/// throwing, so a screen never has to guess what an exception meant.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => '$runtimeType($code): $message';
}

/// No connectivity, timeout, or an unreachable backend.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

/// Sign-in required, expired session, wrong credentials.
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

/// The caller is signed in but not allowed to do this.
class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {super.code});
}

/// The request was well-formed but rejected by a business rule (daily cap
/// reached, not enough coins, already claimed…).
class OperationFailure extends Failure {
  const OperationFailure(super.message, {super.code});
}

/// Something we did not anticipate. The real error is logged, never shown.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([
    super.message = 'Something went wrong. Please try again.',
    // ignore: unused_element_parameter
    String? code,
  ]) : super(code: code);
}
