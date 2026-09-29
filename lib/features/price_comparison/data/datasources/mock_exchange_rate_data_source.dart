import '../../../../core/constants/fake_rates.dart';
import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';
import '../../../../core/errors/failure.dart';
import 'exchange_rate_data_source.dart';

/// In-memory fake source for tests and previews.
///
/// It is **not** a production fallback: nothing in `lib/` reads it, and the
/// local SQLite cache deliberately starts empty so a first run with no network
/// surfaces the problem instead of quietly showing invented numbers.
class MockExchangeRateDataSource implements ExchangeRateDataSource {
  const MockExchangeRateDataSource();

  @override
  Future<bool> hasCachedData() async => true;

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
}
