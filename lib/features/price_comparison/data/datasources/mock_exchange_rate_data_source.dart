import '../../../../core/constants/fake_rates.dart';
import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';
import '../../../../core/errors/failure.dart';
import 'exchange_rate_data_source.dart';

/// In-memory, synchronous-free fake source used for dev, widget tests and as
/// the seed provider for the SQLite source on first launch.
class MockExchangeRateDataSource implements ExchangeRateDataSource {
  const MockExchangeRateDataSource();

  @override
  Future<List<Currency>> getSupportedCurrencies() async =>
      FakeRates.seed
          .map(
            (s) => Currency(
              code: s.$1,
              name: s.$2,
              symbol: s.$3,
              decimalDigits: s.$4,
            ),
          )
          .toList();

  @override
  Future<double> getPriceInCup(String currencyCode) async {
    final price = FakeRates.priceInCup[currencyCode];
    if (price == null) {
      throw RateNotFoundException('No CUP price for "$currencyCode"');
    }
    return price;
  }

  @override
  Future<CupPricePoint> getCurrentCupPrice() async =>
      FakeRates.series().last;

  @override
  Future<List<CupPricePoint>> getCupPriceHistory() async =>
      FakeRates.series();

  @override
  Future<CupPricePoint> refreshCupPrice() async => FakeRates.series().last;
}