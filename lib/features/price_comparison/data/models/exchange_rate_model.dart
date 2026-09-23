import '../../../../core/domain/entities/currency.dart';
import '../../../../core/domain/entities/exchange_rate.dart';

/// Persistence mapping for [ExchangeRate] backed by the `exchange_rates`
/// table. Naturally a subtype of the domain entity, so repos can return it
/// directly.
class ExchangeRateModel extends ExchangeRate {
  const ExchangeRateModel({
    required super.base,
    required super.quote,
    required super.rate,
    super.updatedAt,
  });

  factory ExchangeRateModel.fromMap(
    Map<String, Object?> map, {
    required Currency base,
    required Currency quote,
  }) =>
      ExchangeRateModel(
        base: base,
        quote: quote,
        rate: (map['rate'] as num).toDouble(),
        updatedAt: (map['updated_at'] as int?) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      );

  Map<String, Object?> toMap(Currency base, Currency quote) => {
        'base_code': base.code,
        'quote_code': quote.code,
        'rate': rate,
        'updated_at': updatedAt?.millisecondsSinceEpoch,
      };
}