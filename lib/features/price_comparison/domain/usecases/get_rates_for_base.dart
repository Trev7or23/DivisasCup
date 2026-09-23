import '../../../../core/domain/entities/currency.dart';
import '../../../../core/domain/entities/exchange_rate.dart';
import '../../../../core/domain/repositories/exchange_rate_repository.dart';
import '../../../../core/errors/failure.dart';

/// Lists every `base -> quote` rate for the given [base] currency.
class GetRatesForBase {
  const GetRatesForBase(this._repository);

  final ExchangeRateRepository _repository;

  Future<List<ExchangeRate>> call(Currency base) async {
    try {
      return await _repository.getRatesForBase(base);
    } on Failure {
      rethrow;
    } catch (error) {
      throw UnexpectedFailure('Failed to load rates for ${base.code} ($error)');
    }
  }
}