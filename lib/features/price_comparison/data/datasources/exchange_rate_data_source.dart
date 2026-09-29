import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';

/// Low-level contract for the local cache that backs every screen.
///
/// Implementations only answer an anchored question — "how many CUP does one
/// unit of X cost?" — plus the currency list and the daily CUP-price history.
/// Cross-rate derivation between two currencies lives in the repository, so no
/// source can end up holding inconsistent pairs.
abstract interface class ExchangeRateDataSource {
  /// Whether a sync has ever landed, i.e. whether
  /// [getSupportedCurrencies] would return anything. Lets the app tell "never
  /// synced" apart from "synced but offline" on a first run with no network.
  Future<bool> hasCachedData();

  Future<List<Currency>> getSupportedCurrencies();

  /// CUP needed to buy 1 unit of [currencyCode]. Throws
  /// `RateNotFoundException` when the currency has no anchored price.
  Future<double> getPriceInCup(String currencyCode);

  /// The price of the US dollar in CUP right now (latest sample).
  Future<CupPricePoint> getCurrentCupPrice();

  /// Daily CUP-price history, oldest first.
  Future<List<CupPricePoint>> getCupPriceHistory();
}
