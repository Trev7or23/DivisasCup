/// A monetary currency. Immutable value object shared by all features.
///
/// Equality is identity-based on the ISO-ish [code] so the same currency
/// created by different layers (mock, SQLite seed, UI) compares equal.
class Currency {
  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    this.decimalDigits = 2,
  });

  /// ISO 4217-style code, e.g. "USD", "MXN".
  final String code;

  /// Human-readable name, e.g. "Mexican Peso".
  final String name;

  /// Display symbol, e.g. "$" or "R$".
  final String symbol;

  /// How many decimal places to use when formatting amounts.
  final int decimalDigits;

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'Currency($code)';
}