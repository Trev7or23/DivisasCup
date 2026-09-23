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

  Map<String, Object?> toMap() => {
        'code': code,
        'name': name,
        'symbol': symbol,
        'decimal_digits': decimalDigits,
      };
}