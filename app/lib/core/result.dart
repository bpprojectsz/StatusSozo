import 'package:statussozo/core/errors/app_error.dart';

/// Explicit success or failure instead of thrown exceptions.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;

  T? get valueOrNull => switch (this) {
    Ok<T>(:final T value) => value,
    Err<T>() => null,
  };

  AppError? get errorOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final AppError error) => error,
  };

  /// Folds both cases into one value.
  R when<R>({
    required R Function(T value) ok,
    required R Function(AppError error) err,
  }) {
    return switch (this) {
      Ok<T>(:final T value) => ok(value),
      Err<T>(:final AppError error) => err(error),
    };
  }

  /// Transforms a success value; a failure passes through unchanged.
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Ok<T>(:final T value) => Ok<R>(transform(value)),
      Err<T>(:final AppError error) => Err<R>(error),
    };
  }
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.error);

  final AppError error;
}
