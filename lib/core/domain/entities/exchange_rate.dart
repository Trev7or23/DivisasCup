import 'currency.dart';

/// A directed conversion rate: how many units of [quote] one [base] buys.
///
/// Rates are always expressed `base -> quote`. The inverse is derived via
/// [inverted] instead of being stored, so the seed can never become
/// inconsistent.
class ExchangeRate {
  const ExchangeRate({
    required this.base,
    required this.quote,
    required this.rate,
    this.updatedAt,
  });

  final Currency base;
  final Currency quote;

  /// Multiplier to go from [base] units to [quote] units.
  final double rate;

  /// When the rate was produced. `null` for purely synthetic data.
  final DateTime? updatedAt;

  /// Converts a [amount] expressed in [base] to its value in [quote].
  double convert(double amount) => amount * rate;

  /// Returns the reciprocal pair (`quote -> base`) with rate `1 / rate`.
  ExchangeRate inverted({DateTime? updatedAt}) => ExchangeRate(
        base: quote,
        quote: base,
        rate: 1 / rate,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is ExchangeRate &&
      other.base == base &&
      other.quote == quote &&
      other.rate == rate;

  @override
  int get hashCode => Object.hash(base, quote, rate);

  @override
  String toString() => 'ExchangeRate(${base.code} -> ${quote.code}, $rate)';
}