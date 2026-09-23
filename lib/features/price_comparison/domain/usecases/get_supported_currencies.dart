import '../../../../core/domain/entities/currency.dart';
import '../../../../core/domain/repositories/exchange_rate_repository.dart';
import '../../../../core/errors/failure.dart';

/// Returns the currency list configured for the app, or a
/// [DataSourceFailure] if none are available.
class GetSupportedCurrencies {
  const GetSupportedCurrencies(this._repository);

  final ExchangeRateRepository _repository;

  Future<List<Currency>> call() async {
    try {
      final currencies = await _repository.getSupportedCurrencies();
      if (currencies.isEmpty) {
        throw const DataSourceFailure('No currencies configured');
      }
      return currencies;
    } on Failure {
      rethrow;
    } catch (error) {
      throw UnexpectedFailure('Failed to load currencies ($error)');
    }
  }
}