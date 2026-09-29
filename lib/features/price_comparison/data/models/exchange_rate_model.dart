import '../../../../core/domain/entities/exchange_rate.dart';

/// Presentational twin of [ExchangeRate].
///
/// There is deliberately no `fromMap`/`toMap` here: a cross rate is *derived*
/// from two CUP anchors and never persisted. Materialising it in the cache
/// would create a third copy of the truth that can drift from its anchors, so
/// the only stored rate is the anchor itself.
class ExchangeRateModel extends ExchangeRate {
  const ExchangeRateModel({
    required super.base,
    required super.quote,
    required super.rate,
    super.updatedAt,
  });
}
