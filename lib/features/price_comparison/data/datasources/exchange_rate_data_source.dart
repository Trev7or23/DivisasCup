import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';

/// Low-level rate source contract.
///
/// Implementations only understand a single anchored question — "how many CUP
/// does one unit of X cost?" — plus the supported currency list and the daily
/// CUP-price history. Cross-rate derivation between two currencies lives in
/// the repository, so every source stays impossible to seed inconsistently.
abstract interface class ExchangeRateDataSource {
  Future<List<Currency>> getSupportedCurrencies();

  /// CUP needed to buy 1 unit of [currencyCode]. Throws [RateNotFoundException]
  /// when the currency has no anchored price.
  Future<double> getPriceInCup(String currencyCode);

  /// The price of the US dollar in CUP right now (today's sample).
  Future<CupPricePoint> getCurrentCupPrice();

  /// Daily CUP-price history, oldest first, up to [seriesDays] points.
  Future<List<CupPricePoint>> getCupPriceHistory();

  /// Persists a fresh synthetic sample for today (idempotent) and re-anchors
  /// dependent rows (USD/MLC/EUR do not have their own sampled series).
  Future<CupPricePoint> refreshCupPrice();
}