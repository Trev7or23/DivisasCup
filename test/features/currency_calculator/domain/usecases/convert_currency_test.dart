import 'package:divisas_cup/core/domain/entities/currency.dart';
import 'package:divisas_cup/core/errors/failure.dart';
import 'package:divisas_cup/features/currency_calculator/domain/usecases/convert_currency.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fakes.dart';

void main() {
  group('ConvertCurrency', () {
    const usd = Currency(code: 'USD', name: 'US Dollar', symbol: r'$');
    const cup = Currency(code: 'CUP', name: 'Cuban Peso', symbol: r'$');

    test('returns the direct base->quote rate and converts correctly', () async {
      final usecase = ConvertCurrency(FakeExchangeRateRepository());
      final rate = await usecase(from: usd, to: cup);
      expect(rate.rate, 720);
      expect(rate.convert(10), 7200);
    });

    test('returns the inverse rate when bases are swapped', () async {
      final usecase = ConvertCurrency(FakeExchangeRateRepository());
      final rate = await usecase(from: cup, to: usd);
      expect(rate.rate, closeTo(1 / 720, 1e-12));
    });

    test('wraps backend errors into UnexpectedFailure', () async {
      final usecase = ConvertCurrency(
        FakeExchangeRateRepository(failOnRates: true),
      );
      expect(usecase(from: usd, to: cup), throwsA(isA<UnexpectedFailure>()));
    });
  });
}