/// Typed failure hierarchy. UI maps a [Failure] to a localized message via
/// its subtypes; unknown exceptions are wrapped with [failureFrom].
sealed class Failure implements Exception {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A data source could not be read (I/O, missing row, bad response).
class DataSourceFailure extends Failure {
  const DataSourceFailure(super.message);
}

/// Requested (base, quote) pair has no known rate.
class RateNotFoundException extends Failure {
  const RateNotFoundException(super.message);
}

/// The currency is not among the supported set.
class CurrencyNotFoundException extends Failure {
  const CurrencyNotFoundException(super.message);
}

/// Any non-`Failure` exception surfaced from deeper layers.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}

/// Build-time configuration is missing or unsafe. Fatal: it is thrown in
/// `main()` before the app renders, so it never reaches the UI as a
/// localized message.
class ConfigFailure extends Failure {
  const ConfigFailure(super.message);
}

/// Normalizes any thrown object into a [Failure] for presentation.
Failure failureFrom(Object error) {
  if (error is Failure) return error;
  return UnexpectedFailure('Unexpected error: $error');
}