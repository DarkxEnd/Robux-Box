import 'failure.dart';

/// A success-or-failure wrapper used by every repository and service.
///
/// Sealed so `switch` over it is exhaustive — forgetting the failure branch
/// becomes a compile error rather than a crash in front of a user.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Ok<T>;
  const factory Result.failure(Failure failure) = Err<T>;

  bool get isSuccess => this is Ok<T>;
  bool get isFailure => this is Err<T>;

  T? get valueOrNull => this is Ok<T> ? (this as Ok<T>).value : null;
  Failure? get failureOrNull =>
      this is Err<T> ? (this as Err<T>).failure : null;

  /// Folds both branches into a single value.
  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) => switch (this) {
    Ok<T>(:final value) => success(value),
    Err<T>(failure: final f) => failure(f),
  };

  /// Transforms a success value, leaving a failure untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Result<R>.success(transform(value)),
    Err<T>(failure: final f) => Result<R>.failure(f),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
