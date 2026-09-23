import 'package:intl/intl.dart';

import '../domain/entities/currency.dart';

/// Centralized number formatting so every screen renders amounts and rates the
/// same way (ES/CU locale style: comma thousands, dot decimals).
abstract final class CurrencyFormatter {
  /// e.g. `24.00 MXN` using the currency's own [Currency.decimalDigits].
  static String amount(double value, Currency currency) =>
      '${NumberFormat(_pattern(currency.decimalDigits)).format(value)} '
      '${currency.code}';

  /// e.g. `$24.00` — symbol + amount without code.
  static String symbolic(double value, Currency currency) =>
      currency.symbol + NumberFormat(_pattern(currency.decimalDigits)).format(value);

  /// Rates use up to 6 significant decimals, trailing zeros trimmed.
  static String rate(double value) =>
      NumberFormat('#,##0.######').format(value);

  /// Local-midnight date shifted by [days] (negative = past).
  static DateTime dayShift(DateTime from, int days) =>
      DateTime(from.year, from.month, from.day).add(Duration(days: days));

  static String _pattern(int decimalDigits) =>
      decimalDigits <= 0 ? '#,##0' : '#,##0.${'0' * decimalDigits}';
}