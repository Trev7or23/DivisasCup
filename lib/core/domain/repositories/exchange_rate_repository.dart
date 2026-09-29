import '../entities/cup_price_point.dart';
import '../entities/currency.dart';
import '../entities/exchange_rate.dart';

/// Contract the presentation and use-case layers depend on.
///
/// Implementations live in each feature's `data/` layer. Swapping the backend
/// only changes which implementation is wired in `main.dart`; nothing else in
/// the app needs to change.
abstract interface class ExchangeRateRepository {
  /// Whether a sync has ever landed, i.e. whether [getSupportedCurrencies]
  /// would return anything. Lets the app tell "never synced" apart from
  /// "synced but offline" on a first run with no network.
  Future<bool> hasCachedData();

  Future<List<Currency>> getSupportedCurrencies();

  Future<ExchangeRate> getRate({
    required Currency base,
    required Currency quote,
  });

  /// All rates from [base] to every other supported currency.
  Future<List<ExchangeRate>> getRatesForBase(Currency base);

  /// Latest CUP price point.
  Future<CupPricePoint> getCurrentCupPrice();

  /// Full CUP price series, oldest first.
  Future<List<CupPricePoint>> getCupPriceHistory();
}