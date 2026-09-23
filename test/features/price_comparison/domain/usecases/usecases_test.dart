import 'package:divisas_cup/core/domain/entities/currency.dart';
import 'package:divisas_cup/core/errors/failure.dart';
import 'package:divisas_cup/features/price_comparison/domain/usecases/get_rates_for_base.dart';
import 'package:divisas_cup/features/price_comparison/domain/usecases/get_supported_currencies.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fakes.dart';

void main() {
  group('GetSupportedCurrencies', () {
    test('returns the supported currency list', () async {
      final usecase =
          GetSupportedCurrencies(FakeExchangeRateRepository());
      final currencies = await usecase();
      expect(
        currencies.map((c) => c.code),
        ['CUP', 'USD', 'MLC', 'EUR'],
      );
    });

    test('wraps unknown backend errors into UnexpectedFailure', () async {
      final usecase = GetSupportedCurrencies(
        FakeExchangeRateRepository(failOnCurrencies: true),
      );
      expect(usecase(), throwsA(isA<UnexpectedFailure>()));
    });
  });

  group('GetRatesForBase', () {
    test('derives every non-base pair', () async {
      final usecase = GetRatesForBase(FakeExchangeRateRepository());
      const usd = Currency(code: 'USD', name: 'US Dollar', symbol: r'$');
      final rates = await usecase(usd);
      expect(rates.length, 3);
      expect(rates.every((r) => r.base == usd), isTrue);
      expect(
        rates.map((r) => r.quote.code).toSet(),
        {'CUP', 'MLC', 'EUR'},
      );
      expect(rates.firstWhere((r) => r.quote.code == 'CUP').rate, closeTo(720, 1e-9));
    });
  });
}