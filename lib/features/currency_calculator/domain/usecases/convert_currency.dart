import '../../../../core/domain/entities/currency.dart';
import '../../../../core/domain/entities/exchange_rate.dart';
import '../../../../core/domain/repositories/exchange_rate_repository.dart';
import '../../../../core/errors/failure.dart';

/// Resolves the live `from -> to` rate used by the calculator. The returned
/// [ExchangeRate] exposes [ExchangeRate.convert] and [ExchangeRate.inverted].
class ConvertCurrency {
  const ConvertCurrency(this._repository);

  final ExchangeRateRepository _repository;

  Future<ExchangeRate> call({
    required Currency from,
    required Currency to,
  }) async {
    try {
      return await _repository.getRate(base: from, quote: to);
    } on Failure {
      rethrow;
    } catch (error) {
      throw UnexpectedFailure(
        'Failed to convert ${from.code}->${to.code} ($error)',
      );
    }
  }
}