/// The outcome of an operation that can fail in an expected way.
///
/// Expected failures (a wrong code, no network) travel as [Err] values with a
/// typed failure so callers must handle them. Programming errors still throw.
sealed class Result<T, F> {
  const Result();

  bool get isOk => this is Ok<T, F>;

  /// The value, or null on failure.
  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  R fold<R>(R Function(T value) ok, R Function(F failure) err) => switch (this) {
    Ok(:final value) => ok(value),
    Err(:final failure) => err(failure),
  };
}

final class Ok<T, F> extends Result<T, F> {
  const Ok(this.value);
  final T value;

  @override
  String toString() => 'Ok($value)';
}

final class Err<T, F> extends Result<T, F> {
  const Err(this.failure);
  final F failure;

  @override
  String toString() => 'Err($failure)';
}
