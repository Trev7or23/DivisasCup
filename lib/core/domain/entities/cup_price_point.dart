/// One point in the CUP price history: how many CUP one USD buys on [date].
///
/// Immutable value object, same pattern as [Currency]/[ExchangeRate]; equality
/// compares `date + cupPerUsd` so points built in different layers compare equal.
class CupPricePoint {
  const CupPricePoint({required this.date, required this.cupPerUsd});

  /// Day the price was sampled (local midnight when synthetic).
  final DateTime date;

  /// CUP needed to buy 1 USD that day.
  final double cupPerUsd;

  @override
  bool operator ==(Object other) =>
      other is CupPricePoint &&
      other.date == date &&
      other.cupPerUsd == cupPerUsd;

  @override
  int get hashCode => Object.hash(date, cupPerUsd);

  @override
  String toString() => 'CupPricePoint(${date.toIso8601String()}, $cupPerUsd)';
}