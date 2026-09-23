import 'package:divisas_cup/core/domain/entities/currency.dart';
import 'package:divisas_cup/core/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const usd = Currency(code: 'USD', name: 'US Dollar', symbol: r'$');
  const mxn = Currency(code: 'MXN', name: 'Mexican Peso', symbol: r'$');

  group('CurrencyFormatter', () {
    test('amount appends the currency code with fixed decimals', () {
      expect(CurrencyFormatter.amount(24, mxn), '24.00 MXN');
      expect(CurrencyFormatter.amount(2400, usd), '2,400.00 USD');
    });

    test('symbolic uses the currency symbol without the code', () {
      expect(CurrencyFormatter.symbolic(24, usd), r'$24.00');
      expect(CurrencyFormatter.symbolic(5.2, mxn), r'$5.20');
    });

    test('rate trims trailing zeros but keeps enough precision', () {
      expect(CurrencyFormatter.rate(24), '24');
      expect(CurrencyFormatter.rate(1 / 24), '0.041667');
    });
  });
}