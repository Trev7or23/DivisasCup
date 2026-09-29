import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';

/// One server read, already parsed and ready to be stored verbatim.
///
/// [currencies] is in display order and [priceInCup] holds one anchor per
/// currency, so the pair can be handed straight to the local cache without the
/// repository re-deriving anything.
class RemoteRatesSnapshot {
  const RemoteRatesSnapshot({
    required this.currencies,
    required this.priceInCup,
    required this.series,
  });

  final List<Currency> currencies;

  /// How many CUP one unit of each currency buys, keyed by currency code.
  final Map<String, double> priceInCup;

  /// Daily CUP-per-USD history, oldest first.
  final List<CupPricePoint> series;

  /// Whether this snapshot is usable as a replacement for the local cache.
  ///
  /// Requires at least one currency. A zero-currency read is treated as
  /// corruption rather than as a legitimately empty server, because replacing
  /// the cache with it would leave the app with nothing to show while the user
  /// had perfectly good data a moment ago.
  ///
  /// An empty [series], by contrast, is allowed: a server that has not
  /// collected daily prices yet still serves working conversions, and
  /// rejecting the whole snapshot over it would strand the app on a first
  /// launch.
  bool get isUsable => currencies.isNotEmpty;
}
