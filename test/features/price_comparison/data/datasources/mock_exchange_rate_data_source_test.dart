import 'package:divisas_cup/core/constants/fake_rates.dart';
import 'package:divisas_cup/core/errors/failure.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/mock_exchange_rate_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockExchangeRateDataSource', () {
    const source = MockExchangeRateDataSource();

    test('reports cached data (unlike the real cache, it always answers)',
        () async {
      expect(await source.hasCachedData(), isTrue);
    });

    test('exposes the seeded currencies in order', () async {
      final currencies = await source.getSupportedCurrencies();
      expect(
        currencies.map((c) => c.code),
        ['CUP', 'USD', 'MLC', 'EUR'],
      );
      expect(currencies.first.symbol, r'$');
      expect(currencies.last.symbol, '€');
    });

    test('returns CUP-anchored prices', () async {
      expect(await source.getPriceInCup('CUP'), 1);
      expect(await source.getPriceInCup('USD'), 720);
      expect(await source.getPriceInCup('MLC'), 720);
      expect(await source.getPriceInCup('EUR'), closeTo(777.6, 1e-9));
    });

    test('throws RateNotFoundException for unknown codes', () {
      expect(
        source.getPriceInCup('XXX'),
        throwsA(isA<RateNotFoundException>()),
      );
    });

    test('exposes the current CUP price and the daily history', () async {
      expect(await source.getCurrentCupPrice(), FakeRates.series().last);
      expect(await source.getCupPriceHistory(), FakeRates.series());
    });
  });
}