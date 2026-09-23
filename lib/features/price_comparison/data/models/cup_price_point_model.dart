import '../../../../core/domain/entities/cup_price_point.dart';

/// Persistence twin of [CupPricePoint]; owns the DB row shape so the domain
/// object stays pure Dart.
class CupPricePointModel {
  const CupPricePointModel({required this.date, required this.cupPerUsd});

  final DateTime date;
  final double cupPerUsd;

  factory CupPricePointModel.fromPoint(CupPricePoint point) =>
      CupPricePointModel(date: point.date, cupPerUsd: point.cupPerUsd);

  factory CupPricePointModel.fromMap(Map<String, Object?> map) =>
      CupPricePointModel(
        date: DateTime.fromMillisecondsSinceEpoch(map['sampled_at']! as int),
        cupPerUsd: (map['cup_per_usd']! as num).toDouble(),
      );

  Map<String, Object?> toMap() => {
        'sampled_at': date.millisecondsSinceEpoch,
        'cup_per_usd': cupPerUsd,
      };

  CupPricePoint toPoint() =>
      CupPricePoint(date: date, cupPerUsd: cupPerUsd);
}