import 'dart:math' as math;

import '../domain/entities/cup_price_point.dart';

/// Sample anchored rates used for the fully-offline first phase.
///
/// The anchor is the Cuban Peso: [seed] holds each currency's `priceInCup`,
/// i.e. how many CUP one unit of that currency buys. Cross-rates are derived
/// at the repository level
/// (`rate A->B = priceInCup(A) / priceInCup(B)`), so the seed can never
/// contain conflicting hand-written pairs and adding a currency is a
/// single-line change.
class FakeRates {
  const FakeRates._();

  /// `(code, name, symbol, decimalDigits, priceInCup)`.
  static const List<(String, String, String, int, double)> seed = [
    ('CUP', 'Cuban Peso', r'$', 2, 1.0),
    ('USD', 'US Dollar', r'$', 2, 720.0),
    ('MLC', 'MLC', r'$', 2, 720.0),
    ('EUR', 'Euro', r'€', 2, 777.6),
  ];

  static Map<String, double> get priceInCup => {
        for (final (code, _, _, _, price) in seed) code: price,
      };

  /// Length of the seeded daily CUP-price series.
  static const int seriesDays = 90;

  /// Deterministic ~90-day daily series ending exactly at the current USD
  /// price (720 CUP), so the "last week" point always lands on the day
  /// `today - 7 days`. No randomness: value(0) = 480 and value(seriesDays-1)
  /// = 720 exactly (sine term is 0 at both ends); slope + oscillation keep it
  /// monotonically increasing.
  static List<CupPricePoint> series({DateTime? relativeTo}) {
    final now = relativeTo ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final n = seriesDays - 1;
    return List.generate(seriesDays, (i) {
      final value = 480.0 +
          240.0 * (i / n) +
          6.0 * math.sin(math.pi * i / n * 3.0);
      return CupPricePoint(
        date: today.subtract(Duration(days: n - i)),
        cupPerUsd: value,
      );
    });
  }
}
