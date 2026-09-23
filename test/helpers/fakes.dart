import 'package:divisas_cup/core/domain/entities/cup_price_point.dart';
import 'package:divisas_cup/core/domain/entities/currency.dart';
import 'package:divisas_cup/core/domain/entities/exchange_rate.dart';
import 'package:divisas_cup/core/domain/repositories/exchange_rate_repository.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/mock_exchange_rate_data_source.dart';
import 'package:divisas_cup/features/price_comparison/data/repositories/exchange_rate_repository_impl.dart';

/// Repository double used by widget/usecase tests. Success behaviour reuses
/// the real derivation logic on top of [MockExchangeRateDataSource] (no
/// SQLite/plugin needed); the `failOn*` flags simulate backend errors.
class FakeExchangeRateRepository implements ExchangeRateRepository {
  FakeExchangeRateRepository({
    this.failOnCurrencies = false,
    this.failOnRates = false,
    this.failOnSeries = false,
  }) : _delegate = ExchangeRateRepositoryImpl(
          dataSource: const MockExchangeRateDataSource(),
        );

  final bool failOnCurrencies;
  final bool failOnRates;
  final bool failOnSeries;
  final ExchangeRateRepositoryImpl _delegate;

  @override
  Future<List<Currency>> getSupportedCurrencies() async {
    if (failOnCurrencies) throw StateError('boom');
    return _delegate.getSupportedCurrencies();
  }

  @override
  Future<ExchangeRate> getRate({
    required Currency base,
    required Currency quote,
  }) async {
    if (failOnRates) throw StateError('boom');
    return _delegate.getRate(base: base, quote: quote);
  }

  @override
  Future<List<ExchangeRate>> getRatesForBase(Currency base) async {
    if (failOnRates) throw StateError('boom');
    return _delegate.getRatesForBase(base);
  }

  @override
  Future<CupPricePoint> getCurrentCupPrice() async {
    if (failOnSeries) throw StateError('boom');
    return _delegate.getCurrentCupPrice();
  }

  @override
  Future<List<CupPricePoint>> getCupPriceHistory() async {
    if (failOnSeries) throw StateError('boom');
    return _delegate.getCupPriceHistory();
  }

  @override
  Future<CupPricePoint> refreshCupPrice() async {
    if (failOnSeries) throw StateError('boom');
    return _delegate.refreshCupPrice();
  }
}