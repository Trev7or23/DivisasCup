import 'package:divisas_cup/core/domain/entities/currency.dart';
import 'package:divisas_cup/core/domain/entities/exchange_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const usd = Currency(code: 'USD', name: 'US Dollar', symbol: r'$');
  const mxn = Currency(code: 'MXN', name: 'Mexican Peso', symbol: r'$');

  group('ExchangeRate', () {
    const pair = ExchangeRate(base: usd, quote: mxn, rate: 24);

    test('converts amounts in the base direction', () {
      expect(pair.convert(100), 2400);
      expect(pair.convert(1), 24);
    });

    test('inverted() flips base/quote and uses the reciprocal rate', () {
      final inverse = pair.inverted();
      expect(inverse.base, mxn);
      expect(inverse.quote, usd);
      expect(inverse.rate, closeTo(1 / 24, 1e-12));
      expect(inverse.convert(24), closeTo(1, 1e-12));
    });

    test('equality is by base, quote and rate', () {
      expect(pair, const ExchangeRate(base: usd, quote: mxn, rate: 24));
      expect(pair, isNot(const ExchangeRate(base: usd, quote: mxn, rate: 23)));
      expect(pair.hashCode, const ExchangeRate(base: usd, quote: mxn, rate: 24).hashCode);
    });
  });
}