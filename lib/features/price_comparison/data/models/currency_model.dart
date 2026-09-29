import '../../../../core/domain/entities/currency.dart';

/// Database/JSON mapping for [Currency]. Adds `fromMap`/`toMap` without
/// polluting the domain entity with persistence concerns.
class CurrencyModel extends Currency {
  const CurrencyModel({
    required super.code,
    required super.name,
    required super.symbol,
    super.decimalDigits = 2,
  });

  factory CurrencyModel.fromEntity(Currency currency) => CurrencyModel(
        code: currency.code,
        name: currency.name,
        symbol: currency.symbol,
        decimalDigits: currency.decimalDigits,
      );

  factory CurrencyModel.fromMap(Map<String, Object?> map) => CurrencyModel(
        code: map['code'] as String,
        name: map['name'] as String,
        symbol: map['symbol'] as String,
        decimalDigits: map['decimal_digits'] as int? ?? 2,
      );

  /// [sortOrder] is 1-based display position, mirroring the server's own
  /// ordering. It is written but not read back: [fromMap] deliberately ignores
  /// it because `getSupportedCurrencies` already sorts by that column.
  Map<String, Object?> toMap({required int sortOrder}) => {
        'code': code,
        'name': name,
        'symbol': symbol,
        'decimal_digits': decimalDigits,
        'sort_order': sortOrder,
      };
}