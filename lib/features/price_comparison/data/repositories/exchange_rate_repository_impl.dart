import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';
import '../../../../core/domain/entities/exchange_rate.dart';
import '../../../../core/domain/repositories/exchange_rate_repository.dart';
import '../../../../core/errors/failure.dart';
import '../datasources/exchange_rate_data_source.dart';
import '../models/exchange_rate_model.dart';

/// Bridge between the [ExchangeRateDataSource] implementations and the
/// [ExchangeRateRepository] contract consumed by use cases and widgets.
///
/// Derives `base -> quote` from the two CUP anchors:
/// `rate(A -> B) = priceInCup(A) / priceInCup(B)`.
class ExchangeRateRepositoryImpl implements ExchangeRateRepository {
  ExchangeRateRepositoryImpl({required this.dataSource});

  final ExchangeRateDataSource dataSource;

  @override
  Future<List<Currency>> getSupportedCurrencies() async {
    try {
      return await dataSource.getSupportedCurrencies();
    } on Failure {
      rethrow;
    } catch (error) {
      throw DataSourceFailure('Could not read currencies ($error)');
    }
  }

  @override
  Future<ExchangeRate> getRate({
    required Currency base,
    required Currency quote,
  }) async {
    try {
      return await _derive(base: base, quote: quote);
    } on Failure {
      rethrow;
    } catch (error) {
      throw DataSourceFailure(
        'Could not derive ${base.code}->${quote.code} ($error)',
      );
    }
  }

  @override
  Future<List<ExchangeRate>> getRatesForBase(Currency base) async {
    try {
      final currencies = await dataSource.getSupportedCurrencies();
      final rates = <ExchangeRate>[];
      for (final quote in currencies) {
        if (quote == base) continue;
        rates.add(await _derive(base: base, quote: quote));
      }
      return rates;
    } on Failure {
      rethrow;
    } catch (error) {
      throw DataSourceFailure('Could not list rates for ${base.code} ($error)');
    }
  }

  Future<ExchangeRate> _derive({
    required Currency base,
    required Currency quote,
  }) async {
    final basePrice = await dataSource.getPriceInCup(base.code);
    final quotePrice = await dataSource.getPriceInCup(quote.code);
    return ExchangeRateModel(
      base: base,
      quote: quote,
      rate: basePrice / quotePrice,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<CupPricePoint> getCurrentCupPrice() async {
    try {
      return await dataSource.getCurrentCupPrice();
    } on Failure {
      rethrow;
    } catch (error) {
      throw DataSourceFailure('Could not read current CUP price ($error)');
    }
  }

  @override
  Future<List<CupPricePoint>> getCupPriceHistory() async {
    try {
      return await dataSource.getCupPriceHistory();
    } on Failure {
      rethrow;
    } catch (error) {
      throw DataSourceFailure('Could not read CUP price history ($error)');
    }
  }

  @override
  Future<CupPricePoint> refreshCupPrice() async {
    try {
      return await dataSource.refreshCupPrice();
    } on Failure {
      rethrow;
    } catch (error) {
      throw DataSourceFailure('Could not refresh CUP price ($error)');
    }
  }
}